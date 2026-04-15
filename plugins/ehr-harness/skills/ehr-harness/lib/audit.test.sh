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

echo "ALL DRIFT COMPUTE TESTS PASSED (Task 7)"
