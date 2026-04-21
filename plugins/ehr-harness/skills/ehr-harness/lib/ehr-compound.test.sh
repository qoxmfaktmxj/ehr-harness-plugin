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

# Windows git-bash 에서 fixture 가 CRLF 로 체크아웃되는 drift 가 다시 발생해도
# (예: .gitattributes 가 부분 적용된 환경) 테스트가 false-fail 나지 않도록
# 양쪽의 CR 바이트를 제거한 뒤 비교한다. 정상(LF only) 환경에서는 tr 가 no-op.
_diff_lf() {
  diff -u <(tr -d '\r' < "$1") <(tr -d '\r' < "$2")
}

# ── case_compound_new: 섹션 말미에 신규 블록 추가 ──
cp "$FX/case_compound_new.md" "$TMP/target.md"
ehr_compound_upsert "$TMP/target.md" "EHR-COMPOUND" \
  "2026-04-18-paycalc-trigger" \
  "- \`PayCalcController.calculate()\` → \`P_CPN_CAL_PAY_MAIN\` 호출"
_diff_lf "$FX/case_compound_new.expected.md" "$TMP/target.md" >/dev/null \
  && pass "case_compound_new: 신규 블록 삽입" \
  || fail "case_compound_new: diff mismatch
$(_diff_lf "$FX/case_compound_new.expected.md" "$TMP/target.md")"

# ── case_compound_update: 기존 id 블록 덮어쓰기 ──
cp "$FX/case_compound_update.md" "$TMP/target.md"
ehr_compound_upsert "$TMP/target.md" "EHR-COMPOUND" \
  "upd-id" \
  "- 갱신된 내용 (새 revision)"
_diff_lf "$FX/case_compound_update.expected.md" "$TMP/target.md" >/dev/null \
  && pass "case_compound_update: 기존 id 덮어쓰기" \
  || fail "case_compound_update: diff mismatch
$(_diff_lf "$FX/case_compound_update.expected.md" "$TMP/target.md")"

# ── case_compound_preserve: 마커 외부 영역 보존 ──
cp "$FX/case_compound_preserve.md" "$TMP/target.md"
ehr_compound_upsert "$TMP/target.md" "EHR-COMPOUND" \
  "exists" \
  "- 갱신된 자동 기록"
_diff_lf "$FX/case_compound_preserve.expected.md" "$TMP/target.md" >/dev/null \
  && pass "case_compound_preserve: 외부 영역 보존" \
  || fail "case_compound_preserve: diff mismatch
$(_diff_lf "$FX/case_compound_preserve.expected.md" "$TMP/target.md")"

# ── ehr_compound_remove: 블록 제거 ──
cp "$FX/case_compound_preserve.md" "$TMP/target.md"
ehr_compound_remove "$TMP/target.md" "EHR-COMPOUND" "exists"
grep -q "EHR-COMPOUND:BEGIN exists" "$TMP/target.md" \
  && fail "ehr_compound_remove: 블록이 여전히 존재" \
  || pass "ehr_compound_remove: 블록 제거됨"
# 외부 문단은 살아있어야 함
grep -q "사용자가 수동 작성한 설명 문단" "$TMP/target.md" \
  && pass "ehr_compound_remove: 외부 영역 보존" \
  || fail "ehr_compound_remove: 외부 영역 손실"

# ── ehr_compound_list: id 목록 ──
printf '%s\n' '<!-- EHR-COMPOUND:BEGIN a1 -->' 'x' '<!-- EHR-COMPOUND:END a1 -->' \
              '<!-- EHR-COMPOUND:BEGIN b2 -->' 'y' '<!-- EHR-COMPOUND:END b2 -->' > "$TMP/list.md"
RESULT=$(ehr_compound_list "$TMP/list.md" "EHR-COMPOUND")
echo "$RESULT" | grep -q '^a1$' \
  && pass "ehr_compound_list: a1 감지" \
  || fail "ehr_compound_list: a1 missing ($RESULT)"
echo "$RESULT" | grep -q '^b2$' \
  && pass "ehr_compound_list: b2 감지" \
  || fail "ehr_compound_list: b2 missing ($RESULT)"

# ── 불변식 1 보호: corrupt 마커 상태에서 upsert 는 abort + 외부 prose 보존 ──
# case A: 2 BEGIN + 1 END (orphan begin) — user prose 가 있어야 보존 검증 가능
cp "$FX/case_marker_corrupt_dup_begin.md" "$TMP/corrupt_a.md"
BEFORE=$(cat "$TMP/corrupt_a.md")
ERR_A=$(ehr_compound_upsert "$TMP/corrupt_a.md" "EHR-COMPOUND" "X" "- 갱신 시도" 2>&1 >/dev/null)
RC_A=$?
[[ $RC_A -ne 0 ]] \
  && pass "corrupt_dup_begin: upsert abort (non-zero 리턴)" \
  || fail "corrupt_dup_begin: upsert 가 abort 되어야 함 (0 리턴)"
echo "$ERR_A" | grep -q "마커 corruption 감지" \
  && pass "corrupt_dup_begin: stderr 에 corruption 메시지 포함" \
  || fail "corrupt_dup_begin: corruption 메시지 누락 ($ERR_A)"
AFTER=$(cat "$TMP/corrupt_a.md")
[[ "$BEFORE" == "$AFTER" ]] \
  && pass "corrupt_dup_begin: 파일 내용 불변 (외부 prose 보존)" \
  || fail "corrupt_dup_begin: 파일이 변경됨 — 불변식 1 위반"

# case B: 1 BEGIN + 0 END (missing end)
cp "$FX/case_marker_corrupt_missing_end.md" "$TMP/corrupt_b.md"
BEFORE=$(cat "$TMP/corrupt_b.md")
ERR_B=$(ehr_compound_upsert "$TMP/corrupt_b.md" "EHR-COMPOUND" "Y" "- 갱신 시도" 2>&1 >/dev/null)
RC_B=$?
[[ $RC_B -ne 0 ]] \
  && pass "corrupt_missing_end: upsert abort" \
  || fail "corrupt_missing_end: upsert 가 abort 되어야 함"
echo "$ERR_B" | grep -q "마커 corruption 감지" \
  && pass "corrupt_missing_end: stderr 에 corruption 메시지 포함" \
  || fail "corrupt_missing_end: corruption 메시지 누락 ($ERR_B)"
AFTER=$(cat "$TMP/corrupt_b.md")
[[ "$BEFORE" == "$AFTER" ]] \
  && pass "corrupt_missing_end: 파일 내용 불변" \
  || fail "corrupt_missing_end: 파일이 변경됨 — 불변식 1 위반"

# 신규 파일(0 BEGIN + 0 END) 은 정상 동작해야 함
rm -f "$TMP/fresh.md"
ehr_compound_upsert "$TMP/fresh.md" "EHR-COMPOUND" "fresh-id" "- 신규 내용" \
  && pass "fresh file: upsert 성공" \
  || fail "fresh file: upsert 실패"
grep -q "EHR-COMPOUND:BEGIN fresh-id" "$TMP/fresh.md" \
  && pass "fresh file: 블록 생성됨" \
  || fail "fresh file: 블록 없음"

echo "=== ehr-compound.test.sh: 모든 테스트 통과 ==="
