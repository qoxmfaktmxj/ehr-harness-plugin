#!/usr/bin/env bash
# analyze.test.sh — 프로젝트 분석 함수 테스트
#
# 실행: bash analyze.test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/analyze.sh"

FX="$SCRIPT_DIR/fixtures"

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; }

# ── collect_module_map: 3개 모듈 감지 ──
RESULT=$(collect_module_map "$FX/analysis/project_hr50" "ehr5")
echo "$RESULT" | grep -q '"name":"hrm"' \
  && pass "collect_module_map: hrm 모듈 감지" \
  || fail "collect_module_map: hrm missing ($RESULT)"
echo "$RESULT" | grep -q '"name":"cpn"' \
  && pass "collect_module_map: cpn 모듈 감지" \
  || fail "collect_module_map: cpn missing ($RESULT)"
echo "$RESULT" | grep -q '"name":"tim"' \
  && pass "collect_module_map: tim 모듈 감지" \
  || fail "collect_module_map: tim missing ($RESULT)"

# JSON 유효성
echo "$RESULT" | node -e "
  let s='';process.stdin.on('data',d=>s+=d);
  process.stdin.on('end',()=>{
    try{const m=JSON.parse(s);
      if(!Array.isArray(m))throw new Error('not array');
      m.forEach(x=>{if(!x.name||typeof x.file_count!=='number')throw new Error('shape');});
      process.exit(0);
    }catch(e){console.error(e.message);process.exit(1);}
  });
" >/dev/null 2>&1 \
  && pass "collect_module_map: JSON 배열 유효" \
  || fail "collect_module_map: JSON 파싱 실패 ($RESULT)"

# ── collect_session_vars: 4개 세션 변수 (ssnEnterCd, ssnSabun, ssnSearchType, ssnGrpCd) ──
RESULT=$(collect_session_vars "$FX/analysis/project_hr50" "ehr5")
for sv in ssnEnterCd ssnSabun ssnSearchType ssnGrpCd; do
  echo "$RESULT" | grep -q "\"$sv\"" \
    && pass "collect_session_vars: $sv 감지" \
    || fail "collect_session_vars: $sv missing ($RESULT)"
done

# ── collect_authSqlID: 2개 값 감지 ──
RESULT=$(collect_authSqlID "$FX/analysis/project_hr50" "ehr5")
echo "$RESULT" | grep -q '"THRM151"' \
  && pass "collect_authSqlID: THRM151 감지" \
  || fail "collect_authSqlID: THRM151 missing ($RESULT)"
echo "$RESULT" | grep -q '"TCPN201"' \
  && pass "collect_authSqlID: TCPN201 감지" \
  || fail "collect_authSqlID: TCPN201 missing ($RESULT)"

# ── collect_authSqlID: false positive 차단 ──
# 주석/문자열 속 "XXXX999" 류 ID 는 무시해야 하고,
# 실제 paramMap.put 패턴만 감지해야 한다.
RESULT=$(collect_authSqlID "$FX/analysis/project_false_positive" "ehr5")
echo "$RESULT" | grep -q '"TVLD101"' \
  && pass "collect_authSqlID: paramMap.put 패턴 감지 (TVLD101)" \
  || fail "collect_authSqlID: paramMap.put 패턴 미감지 ($RESULT)"
echo "$RESULT" | grep -q '"TVLD202"' \
  && pass "collect_authSqlID: paramMap.put 패턴 감지 (TVLD202)" \
  || fail "collect_authSqlID: paramMap.put 패턴 미감지 ($RESULT)"
for fp in XXXX999 YYYY888 AAAA111 BBBB222 CCCC333; do
  echo "$RESULT" | grep -q "\"$fp\"" \
    && fail "collect_authSqlID: false positive ($fp 주석/문자열에서 검출됨) ($RESULT)" \
    || pass "collect_authSqlID: 주석/문자열 $fp 무시"
done

# ── collect_law_counts: 법칙별 카운트 ──
RESULT=$(collect_law_counts "$FX/analysis/project_hr50" "ehr5")
# GetDataList.do 2번 (hrm, tim) + SaveData.do 1번 (hrm) + ExecPrc.do 1번 (cpn)
echo "$RESULT" | grep -q '"B_getData":2' \
  && pass "collect_law_counts: B_getData=2" \
  || fail "collect_law_counts: B_getData expected 2 ($RESULT)"
echo "$RESULT" | grep -q '"B_saveData":1' \
  && pass "collect_law_counts: B_saveData=1" \
  || fail "collect_law_counts: B_saveData expected 1 ($RESULT)"
echo "$RESULT" | grep -q '"D_execPrc":1' \
  && pass "collect_law_counts: D_execPrc=1" \
  || fail "collect_law_counts: D_execPrc expected 1 ($RESULT)"
# AuthTableService 파일 1개 있으므로 C_hybrid=1
echo "$RESULT" | grep -q '"C_hybrid":1' \
  && pass "collect_law_counts: C_hybrid=1" \
  || fail "collect_law_counts: C_hybrid expected 1 ($RESULT)"

# JSON 유효성
echo "$RESULT" | node -e "
  let s='';process.stdin.on('data',d=>s+=d);
  process.stdin.on('end',()=>{
    try{const m=JSON.parse(s);
      ['A_direct_controller','B_getData','B_saveData','C_hybrid','D_execPrc'].forEach(k=>{
        if(typeof m[k]!=='number')throw new Error('missing or non-number: '+k);
      });
      process.exit(0);
    }catch(e){console.error(e.message);process.exit(1);}
  });
" >/dev/null 2>&1 \
  && pass "collect_law_counts: JSON 객체 유효" \
  || fail "collect_law_counts: JSON 실패 ($RESULT)"

# ── collect_critical_proc: found 배열 ──
RESULT=$(collect_critical_proc "$FX/analysis/project_hr50" "ehr5")
for p in P_CPN_CAL_PAY_MAIN P_HRI_AFTER_PROC_EXEC P_HRI_APP_PATH_INS_AUTO_ALL P_TIM_WORK_HOUR_CHG; do
  echo "$RESULT" | grep -q "\"$p\"" \
    && pass "collect_critical_proc: $p found" \
    || fail "collect_critical_proc: $p missing ($RESULT)"
done

# ── JSON 유효성 (found + missing 배열) ──
echo "$RESULT" | node -e "
  let s='';process.stdin.on('data',d=>s+=d);
  process.stdin.on('end',()=>{
    try{const m=JSON.parse(s);
      if(!Array.isArray(m.found)||!Array.isArray(m.missing))throw new Error('shape');
      process.exit(0);
    }catch(e){console.error(e.message);process.exit(1);}
  });
" >/dev/null 2>&1 \
  && pass "collect_critical_proc: JSON {found, missing} 유효" \
  || fail "collect_critical_proc: JSON 실패 ($RESULT)"

# ── collect_procedure_summary: count + sample ──
RESULT=$(collect_procedure_summary "$FX/analysis/project_hr50" "ehr5")
# 프로시저 4개 (P_CPN_CAL_PAY_MAIN, P_HRI_AFTER_PROC_EXEC, P_HRI_APP_PATH_INS_AUTO_ALL, P_TIM_WORK_HOUR_CHG) + 트리거 1개 (TRG_TIM_405)
echo "$RESULT" | grep -q '"procedure_count":4' \
  && pass "collect_procedure_summary: procedure_count=4" \
  || fail "collect_procedure_summary: procedure_count expected 4 ($RESULT)"
echo "$RESULT" | grep -q '"trigger_count":1' \
  && pass "collect_procedure_summary: trigger_count=1" \
  || fail "collect_procedure_summary: trigger_count expected 1 ($RESULT)"
echo "$RESULT" | grep -q '"procedure_sample"' \
  && pass "collect_procedure_summary: procedure_sample 존재" \
  || fail "collect_procedure_summary: procedure_sample missing ($RESULT)"

# ── build_analysis_json: 통합 JSON 스키마 ──
RESULT=$(build_analysis_json "$FX/analysis/project_hr50" "ehr5")
echo "$RESULT" | node -e "
  let s='';process.stdin.on('data',d=>s+=d);
  process.stdin.on('end',()=>{
    try{const m=JSON.parse(s);
      const required=['analyzed_at','module_map','session_vars','authSqlID','law_counts','critical_proc_found','critical_proc_missing','procedure_count','procedure_sample','trigger_count'];
      required.forEach(k=>{if(!(k in m))throw new Error('missing key: '+k);});
      if(!Array.isArray(m.module_map))throw new Error('module_map not array');
      if(typeof m.law_counts!=='object')throw new Error('law_counts not object');
      if(typeof m.procedure_count!=='number')throw new Error('procedure_count not number');
      process.exit(0);
    }catch(e){console.error(e.message);process.exit(1);}
  });
" >/dev/null 2>&1 \
  && pass "build_analysis_json: 모든 필수 키 + 타입 유효" \
  || fail "build_analysis_json: 스키마 실패 ($RESULT)"

# ── analyzed_at ISO 8601 형식 ──
echo "$RESULT" | grep -qE '"analyzed_at":"[0-9]{4}-[0-9]{2}-[0-9]{2}T' \
  && pass "build_analysis_json: analyzed_at ISO 8601" \
  || fail "build_analysis_json: analyzed_at 형식 이상 ($RESULT)"

# ══════════════════════════════════════════════════════
# Windows 경로 엣지 케이스 (공백/한글)
# 실제 symlink/junction 은 Git Bash 관리자 권한 필요 →
#   파일 복사로 대체. 실제 symlink 는 별도 환경 검증 필요
# ══════════════════════════════════════════════════════

# ── WP-1: 공백 포함 경로에서 collect_module_map 동작 ──
# 시뮬레이션 경로: C:/Program Files (x86)/proj/
SPACE_FX="$FX/analysis/project_space path"
RESULT=$(collect_module_map "$SPACE_FX" "ehr5")
echo "$RESULT" | grep -q '"name":"hrm"' \
  && pass "WP-1 공백경로: collect_module_map hrm 감지" \
  || fail "WP-1 공백경로: collect_module_map 실패 (경로 quoting 문제 의심) ($RESULT)"
echo "$RESULT" | grep -q '"name":"cpn"' \
  && pass "WP-1 공백경로: collect_module_map cpn 감지" \
  || fail "WP-1 공백경로: collect_module_map cpn 누락 ($RESULT)"

# build_analysis_json 도 공백 경로에서 동작해야 함
RESULT=$(build_analysis_json "$SPACE_FX" "ehr5")
echo "$RESULT" | grep -qE '"analyzed_at":"[0-9]{4}-[0-9]{2}-[0-9]{2}T' \
  && pass "WP-1 공백경로: build_analysis_json 정상 반환" \
  || fail "WP-1 공백경로: build_analysis_json 실패 ($RESULT)"

# ── WP-2: 한글 포함 경로에서 collect_module_map 동작 ──
# 시뮬레이션 경로: C:/사용자/홍길동/proj/ 또는 /tmp/한글폴더/
HANGUL_FX="$FX/analysis/project_한글경로"
RESULT=$(collect_module_map "$HANGUL_FX" "ehr5")
echo "$RESULT" | grep -q '"name":"hrm"' \
  && pass "WP-2 한글경로: collect_module_map hrm 감지" \
  || fail "WP-2 한글경로: collect_module_map 실패 (multibyte 경로 문제 의심) ($RESULT)"

# build_analysis_json 도 한글 경로에서 동작해야 함
RESULT=$(build_analysis_json "$HANGUL_FX" "ehr5")
echo "$RESULT" | grep -qE '"analyzed_at":"[0-9]{4}-[0-9]{2}-[0-9]{2}T' \
  && pass "WP-2 한글경로: build_analysis_json 정상 반환" \
  || fail "WP-2 한글경로: build_analysis_json 실패 ($RESULT)"

# ── WP-3 (심볼릭링크 mock): 복사된 프로젝트에서 동작 확인 ──
# 실제 symlink 는 별도 환경 검증 필요 (mklink /J 는 관리자 권한 필요)
MOCK_FX="$FX/analysis/project_space path"
RESULT=$(collect_session_vars "$MOCK_FX" "ehr5")
echo "$RESULT" | grep -q '"ssnEnterCd"' \
  && pass "WP-3 심볼릭링크(mock): collect_session_vars 정상 (복사 대체 픽스처)" \
  || fail "WP-3 심볼릭링크(mock): collect_session_vars 실패 ($RESULT)"

echo "ALL ANALYZE TESTS PASSED (Task 6)"
