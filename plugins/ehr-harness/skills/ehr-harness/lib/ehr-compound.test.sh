#!/usr/bin/env bash
# ehr-compound.test.sh — 마커 머지 헬퍼 테스트
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/ehr-compound.sh"

FX="$SCRIPT_DIR/fixtures/merge/ehr_cycle"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; }

# ── case_compound_new: 섹션 말미에 신규 블록 추가 ──
cp "$FX/case_compound_new.md" "$TMP/target.md"
ehr_compound_upsert "$TMP/target.md" "EHR-COMPOUND" \
  "2026-04-18-paycalc-trigger" \
  "- \`PayCalcController.calculate()\` → \`P_CPN_CAL_PAY_MAIN\` 호출"
diff -u "$FX/case_compound_new.expected.md" "$TMP/target.md" >/dev/null \
  && pass "case_compound_new: 신규 블록 삽입" \
  || fail "case_compound_new: diff mismatch
$(diff -u "$FX/case_compound_new.expected.md" "$TMP/target.md")"

echo "=== ehr-compound.test.sh: 모든 테스트 통과 ==="
