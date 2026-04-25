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

# ── Case D: 중복 마커 → 첫 쌍만 교체 + 나머지 쌍 제거 (orphan 방지) ──
TGT="$TMP/d.md"
cp "$FX/case_d_duplicate_marker.md" "$TGT"
merge_managed_section "$TGT" "$SECTION_ID" "$HEADING" "$NEW_BODY" 2>"$TMP/d.warn"

CNT=$(grep -c "<!-- HARNESS-MANAGED:analysis_snapshot -->" "$TGT")
[ "$CNT" = "1" ] \
  && pass "Case D: 중복 마커 제거 후 start 1개만" \
  || fail "Case D: start 마커 $CNT 개 (기대 1)"

CNT_END=$(grep -c "<!-- /HARNESS-MANAGED:analysis_snapshot -->" "$TGT")
[ "$CNT_END" = "1" ] \
  && pass "Case D: 중복 마커 제거 후 end 1개만" \
  || fail "Case D: end 마커 $CNT_END 개 (기대 1)"

grep -q "두 번째 마커 블록" "$TGT" \
  && fail "Case D: orphan 본문 잔존" \
  || pass "Case D: 두 번째 orphan 본문 제거"

grep -q "분석 시각 | 2026-04-15T12:00:00" "$TGT" \
  && pass "Case D: 첫 쌍에 신규 body 반영" \
  || fail "Case D: 신규 body 반영 실패"

grep -q "## 사용자 메모" "$TGT" \
  && pass "Case D: 사용자 섹션 보존" \
  || fail "Case D: 사용자 섹션 소실"

grep -q "## 마지막 섹션" "$TGT" \
  && pass "Case D: 마지막 섹션 보존" \
  || fail "Case D: 마지막 섹션 소실"

grep -q "중복" "$TMP/d.warn" \
  && pass "Case D: 중복 마커 경고 stderr 출력" \
  || fail "Case D: 중복 마커 경고 미출력"

# ── Case E: 헤딩이 마커에서 5줄 이상 떨어진 경우에도 추출 가능해야 ──
H_OUT=$(extract_section_heading "$FX/case_e_heading_distant.md" "analysis_snapshot")
[ "$H_OUT" = "## 분석 스냅샷 (자동 감별)" ] \
  && pass "extract_section_heading: 멀리 있는 헤딩 (7줄 이상) 추출" \
  || fail "extract_section_heading: 멀리 있는 헤딩 실패 (got '$H_OUT')"

# ══════════════════════════════════════════════════════
# 엣지 케이스: 교차/중첩/orphan 마커 — 명시적 에러 (exit 2) 기대
# 이전엔 교차/중첩 시 파괴적 동작으로 문서 손상 가능했음. 이제 감지+차단.
# ══════════════════════════════════════════════════════

# ── Case F: 같은 ID 중첩 → exit 2 + stderr 경고 ──
TGT="$TMP/f.md"
cp "$FX/case_f_nested_same_id.md" "$TGT"
cp "$TGT" "$TGT.bak"
if merge_managed_section "$TGT" "$SECTION_ID" "$HEADING" "$NEW_BODY" 2>"$TMP/f.warn"; then
  fail "Case F (같은 ID 중첩): exit 0 반환 (기대 exit 2)"
else
  pass "Case F (같은 ID 중첩): 에러 종료"
fi
grep -q "교차\|중첩" "$TMP/f.warn" \
  && pass "Case F: stderr 에 교차/중첩 경고 출력" \
  || fail "Case F: stderr 경고 미출력 (got: $(cat $TMP/f.warn))"
# 파일 파괴 방지 — 원본 그대로여야
diff -q "$TGT" "$TGT.bak" >/dev/null 2>&1 \
  && pass "Case F: 에러 시 파일 원본 보존" \
  || fail "Case F: 파일 변경됨 (파괴적 동작 — 기대: 원본 보존)"

# ── Case G: orphan start (end 누락) → exit 2 ──
TGT="$TMP/g.md"
cp "$FX/case_g_orphan_start.md" "$TGT"
cp "$TGT" "$TGT.bak"
if merge_managed_section "$TGT" "$SECTION_ID" "$HEADING" "$NEW_BODY" 2>"$TMP/g.warn"; then
  fail "Case G (orphan start): exit 0 반환 (기대 exit 2)"
else
  pass "Case G (orphan start): 에러 종료"
fi
grep -q "orphan" "$TMP/g.warn" \
  && pass "Case G: stderr 에 orphan 경고" \
  || fail "Case G: stderr 경고 미출력"
diff -q "$TGT" "$TGT.bak" >/dev/null 2>&1 \
  && pass "Case G: 에러 시 파일 원본 보존" \
  || fail "Case G: 파일 변경됨"

# ── Case H: orphan end (start 누락) → exit 2 ──
TGT="$TMP/h.md"
cp "$FX/case_h_orphan_end.md" "$TGT"
cp "$TGT" "$TGT.bak"
if merge_managed_section "$TGT" "$SECTION_ID" "$HEADING" "$NEW_BODY" 2>"$TMP/h.warn"; then
  fail "Case H (orphan end): exit 0 반환 (기대 exit 2)"
else
  pass "Case H (orphan end): 에러 종료"
fi
grep -q "orphan" "$TMP/h.warn" \
  && pass "Case H: stderr 에 orphan 경고" \
  || fail "Case H: stderr 경고 미출력"
diff -q "$TGT" "$TGT.bak" >/dev/null 2>&1 \
  && pass "Case H: 에러 시 파일 원본 보존" \
  || fail "Case H: 파일 변경됨"

# ── Case I: 3쌍 중복 (non-overlapping) → 첫 쌍 유지 + 2·3쌍 제거 ──
TGT="$TMP/i.md"
cp "$FX/case_i_triple_duplicate.md" "$TGT"
merge_managed_section "$TGT" "$SECTION_ID" "$HEADING" "$NEW_BODY" 2>"$TMP/i.warn"

CNT=$(grep -c "<!-- HARNESS-MANAGED:analysis_snapshot -->" "$TGT")
[ "$CNT" = "1" ] \
  && pass "Case I (3쌍 중복): start 마커 1개만 남음" \
  || fail "Case I: start 마커 $CNT 개 (기대 1)"

CNT_END=$(grep -c "<!-- /HARNESS-MANAGED:analysis_snapshot -->" "$TGT")
[ "$CNT_END" = "1" ] \
  && pass "Case I (3쌍 중복): end 마커 1개만 남음" \
  || fail "Case I: end 마커 $CNT_END 개 (기대 1)"

grep -q "두 번째 쌍" "$TGT" \
  && fail "Case I: 두 번째 쌍 본문 잔존" \
  || pass "Case I: 두 번째 쌍 본문 제거됨"

grep -q "세 번째 쌍" "$TGT" \
  && fail "Case I: 세 번째 쌍 본문 잔존" \
  || pass "Case I: 세 번째 쌍 본문 제거됨"

grep -q "## 중간 사용자 섹션" "$TGT" \
  && pass "Case I: 중간 사용자 섹션 보존" \
  || fail "Case I: 중간 사용자 섹션 소실"

grep -q "## 또 다른 사용자 섹션" "$TGT" \
  && pass "Case I: 또 다른 사용자 섹션 보존" \
  || fail "Case I: 또 다른 사용자 섹션 소실"

grep -q "## 마지막 섹션" "$TGT" \
  && pass "Case I: 마지막 섹션 보존" \
  || fail "Case I: 마지막 섹션 소실"

grep -q "3쌍\|중복" "$TMP/i.warn" \
  && pass "Case I: stderr 에 중복 마커 경고" \
  || fail "Case I: stderr 경고 미출력 (got: $(cat $TMP/i.warn))"

# ══════════════════════════════════════════════════════
# Windows 경로 엣지 케이스 (공백/한글)
# 실제 symlink/junction 은 Git Bash 관리자 권한 필요 →
#   파일 복사로 대체. 실제 symlink 는 별도 환경 검증 필요
# ══════════════════════════════════════════════════════

WIN_FX="$SCRIPT_DIR/fixtures/merge/windows_paths"

# ── WP-1: 공백 포함 경로에서 merge_managed_section 정상 동작 ──
# 시뮬레이션 경로: /tmp/dir with space/ 또는 C:/Program Files (x86)/proj/
SPACE_DIR="$TMP/dir with space"
mkdir -p "$SPACE_DIR"
cp "$WIN_FX/space_path_base.md" "$SPACE_DIR/AGENTS.md"
merge_managed_section "$SPACE_DIR/AGENTS.md" "$SECTION_ID" "$HEADING" "$NEW_BODY"
grep -q "<!-- HARNESS-MANAGED:analysis_snapshot -->" "$SPACE_DIR/AGENTS.md" \
  && pass "WP-1 공백경로: 마커 추가됨" \
  || fail "WP-1 공백경로: 마커 누락 (경로에 공백 포함 시 quoting 실패 의심)"
grep -q "## 사용자 커스텀 메모" "$SPACE_DIR/AGENTS.md" \
  && pass "WP-1 공백경로: 사용자 섹션 보존" \
  || fail "WP-1 공백경로: 사용자 섹션 소실"

# 멱등성 — 공백 경로에서 2회 적용
SHA_SP1=$(sha256sum "$SPACE_DIR/AGENTS.md" | cut -d' ' -f1)
merge_managed_section "$SPACE_DIR/AGENTS.md" "$SECTION_ID" "$HEADING" "$NEW_BODY"
SHA_SP2=$(sha256sum "$SPACE_DIR/AGENTS.md" | cut -d' ' -f1)
[ "$SHA_SP1" = "$SHA_SP2" ] \
  && pass "WP-1 공백경로: 멱등성" \
  || fail "WP-1 공백경로: 멱등성 위반 ($SHA_SP1 vs $SHA_SP2)"

# ── WP-2: 한글 포함 경로에서 merge_managed_section 정상 동작 ──
# 시뮬레이션 경로: C:/사용자/홍길동/proj/ 또는 /tmp/한글폴더/
HANGUL_DIR="$TMP/한글폴더/홍길동프로젝트"
mkdir -p "$HANGUL_DIR"
cp "$WIN_FX/hangul_path_base.md" "$HANGUL_DIR/AGENTS.md"
merge_managed_section "$HANGUL_DIR/AGENTS.md" "$SECTION_ID" "$HEADING" "$NEW_BODY"
grep -q "<!-- HARNESS-MANAGED:analysis_snapshot -->" "$HANGUL_DIR/AGENTS.md" \
  && pass "WP-2 한글경로: 마커 추가됨" \
  || fail "WP-2 한글경로: 마커 누락 (multibyte 경로 처리 실패 의심)"
grep -q "분석 시각 | 2026-04-15T12:00:00" "$HANGUL_DIR/AGENTS.md" \
  && pass "WP-2 한글경로: body 삽입됨" \
  || fail "WP-2 한글경로: body 누락"

# 멱등성 — 한글 경로에서 2회 적용
SHA_HG1=$(sha256sum "$HANGUL_DIR/AGENTS.md" | cut -d' ' -f1)
merge_managed_section "$HANGUL_DIR/AGENTS.md" "$SECTION_ID" "$HEADING" "$NEW_BODY"
SHA_HG2=$(sha256sum "$HANGUL_DIR/AGENTS.md" | cut -d' ' -f1)
[ "$SHA_HG1" = "$SHA_HG2" ] \
  && pass "WP-2 한글경로: 멱등성" \
  || fail "WP-2 한글경로: 멱등성 위반"

# ── WP-3 (심볼릭링크 mock): 복사된 디렉토리에서 동작 확인 ──
# 실제 symlink 는 별도 환경 검증 필요 (mklink /J 는 관리자 권한 필요)
SYMLINK_MOCK="$TMP/symlink_mock"
cp -r "$SCRIPT_DIR/fixtures/merge" "$SYMLINK_MOCK"
MOCK_TGT="$SYMLINK_MOCK/case_a_no_section.md"
merge_managed_section "$MOCK_TGT" "$SECTION_ID" "$HEADING" "$NEW_BODY"
grep -q "<!-- HARNESS-MANAGED:analysis_snapshot -->" "$MOCK_TGT" \
  && pass "WP-3 심볼릭링크(mock): 복사 대체 픽스처에서 merge 정상" \
  || fail "WP-3 심볼릭링크(mock): merge 실패"


# === Stage 7: apply_staged env gate + nonce + scope ===
echo "=== apply_staged env/nonce/scope tests ==="

# 변수 격리를 위한 새 TMP
APPLY_TMP="$(mktemp -d)"
mkdir -p "$APPLY_TMP/.claude/learnings/staged"

# 기본 HARNESS.json
cat > "$APPLY_TMP/.claude/HARNESS.json" <<'JSON'
{"schema_version":5,"profile":"ehr4","ehr_cycle":{"learnings_meta":{"staged_nonces":{}}}}
JSON

# 기본 staged file
cat > "$APPLY_TMP/.claude/learnings/staged/test-topic.md" <<'EOF'
---
topic: test-topic
score: 4
scope: project-local
target: ehr-lessons/SKILL.md
---

## 제안 본문
<!-- EHR-LESSONS:BEGIN test-topic -->
test rule
<!-- EHR-LESSONS:END test-topic -->
EOF

NONCE=$(sha256sum "$APPLY_TMP/.claude/learnings/staged/test-topic.md" | awk '{print $1}')

# HARNESS 의 staged_nonces[topic] 등록 (harvest 가 했을 일)
HFP="$APPLY_TMP/.claude/HARNESS.json" NONCE="$NONCE" node -e "
  const fs=require('fs');
  const p=process.env.HFP;
  const m=JSON.parse(fs.readFileSync(p,'utf8'));
  m.ehr_cycle.learnings_meta.staged_nonces['test-topic']=process.env.NONCE;
  fs.writeFileSync(p, JSON.stringify(m, null, 2));
"

# === gate 1: EHR_AUDIT_APPROVED 없으면 exit 2 ===
( cd "$APPLY_TMP" && bash "$SCRIPT_DIR/merge.sh" apply_staged ".claude/learnings/staged/test-topic.md" ) >/dev/null 2>&1
ec=$?
[ "$ec" = "2" ] && pass "gate1: no AUDIT_APPROVED → exit 2" || fail "gate1: no AUDIT_APPROVED → exit 2 (got $ec)"

# === gate 2: nonce mismatch → exit 3 ===
BAD_NONCE="0000000000000000000000000000000000000000000000000000000000000000"
( cd "$APPLY_TMP" && EHR_AUDIT_APPROVED=1 EHR_NONCE="$BAD_NONCE" \
   bash "$SCRIPT_DIR/merge.sh" apply_staged ".claude/learnings/staged/test-topic.md" ) >/dev/null 2>&1
ec=$?
[ "$ec" = "3" ] && pass "gate2: nonce mismatch → exit 3" || fail "gate2: nonce mismatch → exit 3 (got $ec)"

# === gate 3: org-template reserved → exit 5 ===
sed -i 's/scope: project-local/scope: org-template/' "$APPLY_TMP/.claude/learnings/staged/test-topic.md"
NONCE2=$(sha256sum "$APPLY_TMP/.claude/learnings/staged/test-topic.md" | awk '{print $1}')
HFP="$APPLY_TMP/.claude/HARNESS.json" NONCE="$NONCE2" node -e "
  const fs=require('fs');
  const m=JSON.parse(fs.readFileSync(process.env.HFP,'utf8'));
  m.ehr_cycle.learnings_meta.staged_nonces['test-topic']=process.env.NONCE;
  fs.writeFileSync(process.env.HFP, JSON.stringify(m, null, 2));
"
( cd "$APPLY_TMP" && EHR_AUDIT_APPROVED=1 EHR_NONCE="$NONCE2" \
   bash "$SCRIPT_DIR/merge.sh" apply_staged ".claude/learnings/staged/test-topic.md" ) >/dev/null 2>&1
ec=$?
[ "$ec" = "5" ] && pass "gate3: org-template → exit 5" || fail "gate3: org-template → exit 5 (got $ec)"

# === gate 4: project-local 적용 성공 → staged.applied 이동 + SKILL.md 업데이트 ===
sed -i 's/scope: org-template/scope: project-local/' "$APPLY_TMP/.claude/learnings/staged/test-topic.md"
NONCE3=$(sha256sum "$APPLY_TMP/.claude/learnings/staged/test-topic.md" | awk '{print $1}')
HFP="$APPLY_TMP/.claude/HARNESS.json" NONCE="$NONCE3" node -e "
  const fs=require('fs');
  const m=JSON.parse(fs.readFileSync(process.env.HFP,'utf8'));
  m.ehr_cycle.learnings_meta.staged_nonces['test-topic']=process.env.NONCE;
  fs.writeFileSync(process.env.HFP, JSON.stringify(m, null, 2));
"

mkdir -p "$APPLY_TMP/.claude/skills/ehr-lessons"
echo '# ehr-lessons (project-local)' > "$APPLY_TMP/.claude/skills/ehr-lessons/SKILL.md"

( cd "$APPLY_TMP" && EHR_AUDIT_APPROVED=1 EHR_NONCE="$NONCE3" \
   bash "$SCRIPT_DIR/merge.sh" apply_staged ".claude/learnings/staged/test-topic.md" ) >/dev/null 2>&1
ec=$?
[ "$ec" = "0" ] && pass "gate4: project-local apply success" || fail "gate4: project-local apply success (got $ec)"

# staged.applied 이동
[ -f "$APPLY_TMP/.claude/learnings/staged.applied/test-topic.md" ] && pass "gate4: moved to staged.applied" || fail "gate4: moved to staged.applied"

# SKILL.md 에 marker 블록 append
grep -q 'EHR-LESSONS:BEGIN test-topic' "$APPLY_TMP/.claude/skills/ehr-lessons/SKILL.md" && pass "gate4: SKILL.md updated" || fail "gate4: SKILL.md updated"

# === gate 5: unknown scope → exit 6 ===
mkdir -p "$APPLY_TMP/.claude/learnings/staged"
cat > "$APPLY_TMP/.claude/learnings/staged/u.md" <<'EOF'
---
topic: u
score: 4
scope: weird-unknown-scope
target: AGENTS.md
---
EOF
NONCE_U=$(sha256sum "$APPLY_TMP/.claude/learnings/staged/u.md" | awk '{print $1}')
HFP="$APPLY_TMP/.claude/HARNESS.json" NONCE="$NONCE_U" node -e "
  const fs=require('fs');
  const m=JSON.parse(fs.readFileSync(process.env.HFP,'utf8'));
  m.ehr_cycle.learnings_meta.staged_nonces['u']=process.env.NONCE;
  fs.writeFileSync(process.env.HFP, JSON.stringify(m, null, 2));
"
( cd "$APPLY_TMP" && EHR_AUDIT_APPROVED=1 EHR_NONCE="$NONCE_U" \
   bash "$SCRIPT_DIR/merge.sh" apply_staged ".claude/learnings/staged/u.md" ) >/dev/null 2>&1
ec=$?
[ "$ec" = "6" ] && pass "gate5: unknown scope → exit 6" || fail "gate5: unknown scope → exit 6 (got $ec)"

rm -rf "$APPLY_TMP"

echo ""
echo "=========================================="
echo "  PASSED: $PASS / FAILED: $FAIL"
echo "=========================================="
[ "$FAIL" -eq 0 ] && echo "ALL MERGE TESTS PASSED" && exit 0
exit 1
