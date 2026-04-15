#!/usr/bin/env bash
# merge.test.sh — HARNESS-MANAGED 섹션 병합 유틸 테스트
# 사용: bash merge.test.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/merge.sh"

FX="$SCRIPT_DIR/fixtures/merge"
TMP=$(mktemp -d)
trap "rm -rf '$TMP'" EXIT

PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

SECTION_ID="analysis_snapshot"
HEADING="## 분석 스냅샷 (자동 감별)"
NEW_BODY="| 항목 | 값 |
|------|-----|
| 분석 시각 | 2026-04-15T12:00:00+09:00 |
| 모듈 수 | 19 |

누락된 치명 프로시저: _(없음)_"

# ── Case A: 섹션 없음 → append ──
TGT="$TMP/a.md"
cp "$FX/case_a_no_section.md" "$TGT"
merge_managed_section "$TGT" "$SECTION_ID" "$HEADING" "$NEW_BODY"

grep -q "## 분석 스냅샷 (자동 감별)" "$TGT" \
  && pass "Case A: 섹션 헤더 추가됨" \
  || fail "Case A: 섹션 헤더 누락"

grep -q "<!-- HARNESS-MANAGED:analysis_snapshot -->" "$TGT" \
  && pass "Case A: start 마커 추가됨" \
  || fail "Case A: start 마커 누락"

grep -q "<!-- /HARNESS-MANAGED:analysis_snapshot -->" "$TGT" \
  && pass "Case A: end 마커 추가됨" \
  || fail "Case A: end 마커 누락"

grep -q "분석 시각 | 2026-04-15T12:00:00" "$TGT" \
  && pass "Case A: 신규 body 포함" \
  || fail "Case A: 신규 body 누락"

grep -q "## 사용자 커스텀 메모" "$TGT" \
  && pass "Case A: 사용자 커스텀 섹션 보존" \
  || fail "Case A: 사용자 커스텀 섹션 소실"

grep -q "이건 사용자가 추가한 내용이다. 보존되어야 함." "$TGT" \
  && pass "Case A: 사용자 본문 보존" \
  || fail "Case A: 사용자 본문 소실"

# ── Case B: 제목 존재, 마커 없음 → 제목 유지 + 내부 마커 래핑 + 내용 교체 ──
TGT="$TMP/b.md"
cp "$FX/case_b_heading_only.md" "$TGT"
merge_managed_section "$TGT" "$SECTION_ID" "$HEADING" "$NEW_BODY"

# 제목은 단 1회 (중복 append 금지)
CNT=$(grep -c "^## 분석 스냅샷 (자동 감별)$" "$TGT")
[ "$CNT" = "1" ] \
  && pass "Case B: 제목 중복 없음 (1회)" \
  || fail "Case B: 제목 $CNT회 (기대 1)"

grep -q "<!-- HARNESS-MANAGED:analysis_snapshot -->" "$TGT" \
  && pass "Case B: 마커로 래핑됨" \
  || fail "Case B: 마커 래핑 누락"

grep -q "분석 시각 | 2026-04-15T12:00:00" "$TGT" \
  && pass "Case B: 신규 body 반영" \
  || fail "Case B: 신규 body 반영 실패"

grep -q "2025-10-01T00:00:00" "$TGT" \
  && fail "Case B: 이전 body 가 남아있음 (교체 실패)" \
  || pass "Case B: 이전 body 교체됨"

grep -q "## 사용자 커스텀 메모" "$TGT" \
  && pass "Case B: 사용자 섹션 보존" \
  || fail "Case B: 사용자 섹션 소실"

grep -q "이건 사용자가 추가한 내용. 보존 필수." "$TGT" \
  && pass "Case B: 사용자 본문 보존" \
  || fail "Case B: 사용자 본문 소실"

# ── Case C: 마커 존재 → 내부만 교체 ──
TGT="$TMP/c.md"
cp "$FX/case_c_marker_wrapped.md" "$TGT"
merge_managed_section "$TGT" "$SECTION_ID" "$HEADING" "$NEW_BODY"

CNT=$(grep -c "<!-- HARNESS-MANAGED:analysis_snapshot -->" "$TGT")
[ "$CNT" = "1" ] \
  && pass "Case C: start 마커 중복 없음" \
  || fail "Case C: start 마커 $CNT 회 (기대 1)"

grep -q "분석 시각 | 2026-04-15T12:00:00" "$TGT" \
  && pass "Case C: 신규 body 반영" \
  || fail "Case C: 신규 body 반영 실패"

grep -q "2025-10-01T00:00:00" "$TGT" \
  && fail "Case C: 이전 body 잔존" \
  || pass "Case C: 이전 body 교체됨"

grep -q "## 사용자 커스텀 메모" "$TGT" \
  && pass "Case C: 사용자 섹션 보존" \
  || fail "Case C: 사용자 섹션 소실"

# ── 멱등성: 동일 merge 를 두 번 적용해도 결과 동일 ──
TGT="$TMP/d.md"
cp "$FX/case_a_no_section.md" "$TGT"
merge_managed_section "$TGT" "$SECTION_ID" "$HEADING" "$NEW_BODY"
SHA1=$(sha256sum "$TGT" | cut -d' ' -f1)
merge_managed_section "$TGT" "$SECTION_ID" "$HEADING" "$NEW_BODY"
SHA2=$(sha256sum "$TGT" | cut -d' ' -f1)
[ "$SHA1" = "$SHA2" ] \
  && pass "멱등성: 동일 merge 2회 적용 결과 동일" \
  || fail "멱등성 위반: $SHA1 vs $SHA2"

# ── 다중 섹션: 다른 ID 로 merge 시 기존 섹션 영향 없음 ──
TGT="$TMP/e.md"
cp "$FX/case_c_marker_wrapped.md" "$TGT"
merge_managed_section "$TGT" "auth_model" "## 권한 모델 (자동 감별)" "| key | val |"

grep -q "<!-- HARNESS-MANAGED:auth_model -->" "$TGT" \
  && pass "다중 섹션: 새 섹션 추가" \
  || fail "다중 섹션: 새 섹션 누락"

grep -q "<!-- HARNESS-MANAGED:analysis_snapshot -->" "$TGT" \
  && pass "다중 섹션: 기존 섹션 보존" \
  || fail "다중 섹션: 기존 섹션 소실"

grep -q "2025-10-01T00:00:00" "$TGT" \
  && pass "다중 섹션: 기존 body 보존" \
  || fail "다중 섹션: 기존 body 소실"

# ── 헬퍼: extract_section_body ──
BODY_OUT=$(extract_section_body "$FX/case_c_marker_wrapped.md" "analysis_snapshot")
echo "$BODY_OUT" | grep -q "2025-10-01T00:00:00" \
  && pass "extract_section_body: 마커 사이 본문 반환" \
  || fail "extract_section_body: 본문 누락 (got: $BODY_OUT)"

echo "$BODY_OUT" | grep -q "HARNESS-MANAGED" \
  && fail "extract_section_body: 마커 포함되어 반환됨" \
  || pass "extract_section_body: 마커 제외"

# 미존재 섹션 → exit 2
if extract_section_body "$FX/case_c_marker_wrapped.md" "nonexistent" 2>/dev/null; then
  fail "extract_section_body: 없는 ID 에 성공 반환"
else
  pass "extract_section_body: 없는 ID 는 실패 (exit !=0)"
fi

# ── 헬퍼: extract_section_heading ──
H_OUT=$(extract_section_heading "$FX/case_c_marker_wrapped.md" "analysis_snapshot")
[ "$H_OUT" = "## 분석 스냅샷 (자동 감별)" ] \
  && pass "extract_section_heading: 마커 직전 H2 반환" \
  || fail "extract_section_heading: unexpected '$H_OUT'"

echo ""
echo "=========================================="
echo "  PASSED: $PASS / FAILED: $FAIL"
echo "=========================================="
[ "$FAIL" -eq 0 ] && echo "ALL MERGE TESTS PASSED" && exit 0
exit 1
