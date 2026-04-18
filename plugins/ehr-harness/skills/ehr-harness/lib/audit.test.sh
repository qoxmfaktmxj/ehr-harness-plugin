#!/usr/bin/env bash
# audit.test.sh — drift 계산 + 리포트 렌더링 테스트
#
# 실행: bash audit.test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/audit.sh"

FX="$SCRIPT_DIR/fixtures/audit"

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; }

BEFORE=$(cat "$FX/analysis_before.json")
AFTER_CLEAN=$(cat "$FX/analysis_after_clean.json")
AFTER_MIXED=$(cat "$FX/analysis_after_mixed.json")

# ── compute_drift: clean (변화 없음) ──
RESULT=$(compute_drift "$BEFORE" "$AFTER_CLEAN")
echo "$RESULT" | node -e "
  let s='';process.stdin.on('data',d=>s+=d);
  process.stdin.on('end',()=>{try{const m=JSON.parse(s);
    if(m.module_map.added.length!==0||m.module_map.removed.length!==0)throw new Error('module_map should be empty');
    if(m.session_vars.added.length!==0||m.session_vars.removed.length!==0)throw new Error('session_vars should be empty');
    if(m.critical_proc_found.added.length!==0)throw new Error('critical_proc_found.added should be empty');
    process.exit(0);
  }catch(e){console.error(e.message);process.exit(1);}});
" >/dev/null 2>&1 \
  && pass "compute_drift clean: 모든 diff 배열 비어있음" \
  || fail "compute_drift clean: drift 감지됨 ($RESULT)"

# ── compute_drift: mixed (상/중/하) ──
RESULT=$(compute_drift "$BEFORE" "$AFTER_MIXED")

# module_map.added 에 hrd
echo "$RESULT" | grep -q '"hrd"' \
  && pass "compute_drift mixed: module_map.added에 hrd" \
  || fail "compute_drift mixed: hrd missing ($RESULT)"

# session_vars.added 에 ssnDeptCd
echo "$RESULT" | grep -q '"ssnDeptCd"' \
  && pass "compute_drift mixed: session_vars.added에 ssnDeptCd" \
  || fail "compute_drift mixed: ssnDeptCd missing ($RESULT)"

# critical_proc_found.added 에 P_HRI_AFTER_PROC_EXEC
echo "$RESULT" | grep -q '"P_HRI_AFTER_PROC_EXEC"' \
  && pass "compute_drift mixed: critical_proc_found.added에 P_HRI_AFTER_PROC_EXEC" \
  || fail "compute_drift mixed: P_HRI_AFTER_PROC_EXEC missing ($RESULT)"

# procedure_count 234→238 (+4) 절대값<5 상대값<10% → changed: false
echo "$RESULT" | node -e "
  let s='';process.stdin.on('data',d=>s+=d);
  process.stdin.on('end',()=>{try{const m=JSON.parse(s);
    if(m.procedure_count && m.procedure_count.changed===true)throw new Error('procedure_count should not be changed (below threshold)');
    process.exit(0);
  }catch(e){console.error(e.message);process.exit(1);}});
" >/dev/null 2>&1 \
  && pass "compute_drift: procedure_count 노이즈 필터 (+4 <5)" \
  || fail "compute_drift: procedure_count 필터 실패 ($RESULT)"

# ── drift_importance: 상/중/하 분류 ──
DRIFT=$(compute_drift "$BEFORE" "$AFTER_MIXED")
RESULT=$(drift_importance "$DRIFT")

# high: session_vars.added, critical_proc_found.added
echo "$RESULT" | grep -q '"high"' \
  && pass "drift_importance: high 카테고리 존재" \
  || fail "drift_importance: high missing ($RESULT)"

# medium: module_map.added
echo "$RESULT" | grep -q '"medium"' \
  && pass "drift_importance: medium 카테고리 존재" \
  || fail "drift_importance: medium missing ($RESULT)"

# JSON 유효성
echo "$RESULT" | node -e "
  let s='';process.stdin.on('data',d=>s+=d);
  process.stdin.on('end',()=>{try{const m=JSON.parse(s);
    if(!Array.isArray(m.high))throw new Error('high not array');
    if(!Array.isArray(m.medium))throw new Error('medium not array');
    if(!Array.isArray(m.low))throw new Error('low not array');
    process.exit(0);
  }catch(e){console.error(e.message);process.exit(1);}});
" >/dev/null 2>&1 \
  && pass "drift_importance: {high, medium, low} 배열 구조" \
  || fail "drift_importance: 구조 실패 ($RESULT)"

# high 배열에 session_vars 항목
echo "$RESULT" | grep -q 'session_vars' \
  && pass "drift_importance: session_vars high로 분류" \
  || fail "drift_importance: session_vars 분류 안 됨 ($RESULT)"

# ── render_audit_report: 마크다운 리포트 생성 ──
DRIFT=$(compute_drift "$BEFORE" "$AFTER_MIXED")
IMPORTANCE=$(drift_importance "$DRIFT")
REPORT=$(render_audit_report "$DRIFT" "$IMPORTANCE" "2026-04-15T14:23:01+09:00" "EHR_HR50" "ehr5" "1.2.0" "1.3.0")

# 필수 섹션 헤더
echo "$REPORT" | grep -q "^## 프로젝트 Drift" \
  && pass "render_audit_report: Drift 섹션 존재" \
  || fail "render_audit_report: Drift 섹션 missing"

echo "$REPORT" | grep -q '상\]' \
  && pass "render_audit_report: [상] 라벨 존재" \
  || fail "render_audit_report: [상] label missing"

echo "$REPORT" | grep -q "ssnDeptCd" \
  && pass "render_audit_report: ssnDeptCd 항목 포함" \
  || fail "render_audit_report: ssnDeptCd missing"

# 프로젝트 메타
echo "$REPORT" | grep -q "EHR_HR50" \
  && pass "render_audit_report: 시스템명 포함" \
  || fail "render_audit_report: 시스템명 missing"

echo "$REPORT" | grep -qE "1\\.2\\.0.*1\\.3\\.0" \
  && pass "render_audit_report: 플러그인 버전 전환 표시" \
  || fail "render_audit_report: 버전 전환 missing"

# ── save_audit_report: 파일 쓰기 ──
TMP_R="$(mktemp -d)"
save_audit_report "$REPORT" "$TMP_R/report.md"
[ -f "$TMP_R/report.md" ] && pass "save_audit_report: 파일 생성됨" \
  || fail "save_audit_report: 파일 미생성"
grep -q "^## 프로젝트 Drift" "$TMP_R/report.md" \
  && pass "save_audit_report: 내용 저장됨" \
  || fail "save_audit_report: 내용 누락"
rm -rf "$TMP_R"

# ── compute_drift: 키 순서만 다른 객체는 changed 로 잡지 않음 (stable stringify) ──
REORDER_BEFORE=$(cat "$SCRIPT_DIR/fixtures/scenario_audit_reorder/HARNESS.json" | node -e "
  let s='';process.stdin.on('data',d=>s+=d);
  process.stdin.on('end',()=>{const m=JSON.parse(s);process.stdout.write(JSON.stringify(m.analysis));});
")
REORDER_AFTER=$(cat "$SCRIPT_DIR/fixtures/scenario_audit_reorder/new_analysis.json")

RESULT=$(compute_drift "$REORDER_BEFORE" "$REORDER_AFTER")
echo "$RESULT" | node -e "
  let s='';process.stdin.on('data',d=>s+=d);
  process.stdin.on('end',()=>{try{const m=JSON.parse(s);
    if(m.module_map.changed.length!==0)throw new Error('module_map.changed should be empty for key reorder, got: '+JSON.stringify(m.module_map.changed));
    process.exit(0);
  }catch(e){console.error(e.message);process.exit(1);}});
" >/dev/null 2>&1 \
  && pass "compute_drift reorder: module_map 키 순서 변경은 changed 아님" \
  || fail "compute_drift reorder: 키 순서 차이로 false changed 발생 ($RESULT)"

echo "ALL DRIFT COMPUTE TESTS PASSED (Task 7)"

# ── EHR Cycle 드리프트 (v4) — smoke test ──
TMP_P="$(mktemp -d)"
mkdir -p "$TMP_P/.claude" "$TMP_P/reference" "$TMP_P/skills/domain-knowledge"
cat > "$TMP_P/.claude/HARNESS.json" <<'EHR_JSON_EOF'
{
  "schema_version": 4,
  "ehr_cycle": {
    "compounds": [{"id":"ghost-id","level":"L2","domain":"code_map","files":["reference/CODE_MAP.md"]}],
    "promoted": [{"id":"abc","backup":".ehr-bak/does-not-exist.bak"}]
  }
}
EHR_JSON_EOF
echo "# CODE_MAP" > "$TMP_P/reference/CODE_MAP.md"
echo "# domain" > "$TMP_P/skills/domain-knowledge/SKILL.md"
cat > "$TMP_P/CLAUDE.md" <<'CLAUDE_EOF'
# CLAUDE

<!-- EHR-PREFERENCES:BEGIN -->
FILE_THRESHOLD=3
SUGGEST_MODE=ask
<!-- EHR-PREFERENCES:END -->
CLAUDE_EOF

RESULT=$(ehr_audit_compound_drift "$TMP_P")
echo "$RESULT" | grep -q "orphan_compound:ghost-id" \
  && pass "ehr_audit_compound_drift: orphan_compound 감지" \
  || fail "ehr_audit_compound_drift: ghost-id 미검출 ($RESULT)"

RESULT=$(ehr_audit_stale_promotion "$TMP_P")
echo "$RESULT" | grep -q "stale_promotion::.ehr-bak/does-not-exist.bak" \
  && pass "ehr_audit_stale_promotion: 미존재 백업 감지" \
  || fail "ehr_audit_stale_promotion: 감지 실패 ($RESULT)"

# 정상 preferences: 경고 없어야 함
RESULT=$(ehr_audit_preferences_parse "$TMP_P")
[[ -z "$RESULT" ]] \
  && pass "ehr_audit_preferences_parse: 정상 블록은 조용히 통과" \
  || fail "ehr_audit_preferences_parse: 정상인데 경고 발생 ($RESULT)"

# 깨진 preferences 블록: corruption 감지
cat > "$TMP_P/CLAUDE.md" <<'CORRUPT_EOF'
# CLAUDE

<!-- EHR-PREFERENCES:BEGIN -->
(empty content, no key=value)
<!-- EHR-PREFERENCES:END -->
CORRUPT_EOF
RESULT=$(ehr_audit_preferences_parse "$TMP_P")
echo "$RESULT" | grep -q "preferences_corruption" \
  && pass "ehr_audit_preferences_parse: 빈 블록은 corruption 감지" \
  || fail "ehr_audit_preferences_parse: 빈 블록 감지 실패 ($RESULT)"

rm -rf "$TMP_P"
echo "ALL EHR CYCLE AUDIT TESTS PASSED"
