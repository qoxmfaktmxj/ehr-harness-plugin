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

# ── case_compound_update: 기존 id 블록 덮어쓰기 ──
cp "$FX/case_compound_update.md" "$TMP/target.md"
ehr_compound_upsert "$TMP/target.md" "EHR-COMPOUND" \
  "upd-id" \
  "- 갱신된 내용 (새 revision)"
diff -u "$FX/case_compound_update.expected.md" "$TMP/target.md" >/dev/null \
  && pass "case_compound_update: 기존 id 덮어쓰기" \
  || fail "case_compound_update: diff mismatch
$(diff -u "$FX/case_compound_update.expected.md" "$TMP/target.md")"

# ── case_compound_preserve: 마커 외부 영역 보존 ──
cp "$FX/case_compound_preserve.md" "$TMP/target.md"
ehr_compound_upsert "$TMP/target.md" "EHR-COMPOUND" \
  "exists" \
  "- 갱신된 자동 기록"
diff -u "$FX/case_compound_preserve.expected.md" "$TMP/target.md" >/dev/null \
  && pass "case_compound_preserve: 외부 영역 보존" \
  || fail "case_compound_preserve: diff mismatch
$(diff -u "$FX/case_compound_preserve.expected.md" "$TMP/target.md")"

echo "=== ehr-compound.test.sh: 모든 테스트 통과 ==="
