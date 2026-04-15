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

echo "ALL ANALYZE TESTS PASSED (Task 3)"
