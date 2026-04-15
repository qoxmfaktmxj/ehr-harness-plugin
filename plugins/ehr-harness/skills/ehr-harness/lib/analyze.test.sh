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

echo "ALL ANALYZE TESTS PASSED (Task 3)"
