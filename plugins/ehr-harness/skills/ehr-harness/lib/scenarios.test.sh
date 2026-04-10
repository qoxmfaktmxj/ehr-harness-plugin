#!/usr/bin/env bash
# scenarios.test.sh — 3가지 진입 모드 (fresh / legacy / stamped) 분류 검증
#
# 실행: bash scenarios.test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/harness-state.sh"

FX="$SCRIPT_DIR/fixtures"

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; }

classify_mode() {
  # args: project_dir
  local d="$1"
  local manifest="$d/.claude/HARNESS.json"
  local has_trace=0
  if [ -f "$d/AGENTS.md" ] || ls "$d"/.claude/skills/ehr-* >/dev/null 2>&1; then
    has_trace=1
  fi

  if [ ! -f "$manifest" ] && [ "$has_trace" = "0" ]; then
    echo "fresh"
  elif [ ! -f "$manifest" ] && [ "$has_trace" = "1" ]; then
    echo "legacy"
  elif hs_is_legacy "$manifest"; then
    echo "legacy"
  else
    echo "stamped"
  fi
}

# ── 1. fresh: HARNESS.json 도 AGENTS.md 도 없음 ──
mode=$(classify_mode "$FX/scenario_fresh")
[ "$mode" = "fresh" ] && pass "scenario fresh" || fail "scenario fresh (got: $mode)"

# ── 2. legacy: AGENTS.md 는 있는데 HARNESS.json 없음 ──
mode=$(classify_mode "$FX/scenario_legacy")
[ "$mode" = "legacy" ] && pass "scenario legacy" || fail "scenario legacy (got: $mode)"

# ── 3. stamped: HARNESS.json 이 있고 schema_version 채워짐 ──
# 픽스처에는 .claude/ 가 없고 HARNESS.json 만 있으니, 임시로 .claude/ 에 복사한다.
TMP_STAMPED="$(mktemp -d)"
trap 'rm -rf "$TMP_STAMPED"' EXIT
mkdir -p "$TMP_STAMPED/.claude"
cp "$FX/scenario_stamped/HARNESS.json" "$TMP_STAMPED/.claude/HARNESS.json"
mode=$(classify_mode "$TMP_STAMPED")
[ "$mode" = "stamped" ] && pass "scenario stamped" || fail "scenario stamped (got: $mode)"

# ── 4. legacy by malformed manifest: schema_version 없는 manifest ──
TMP_BAD="$(mktemp -d)"
mkdir -p "$TMP_BAD/.claude"
echo '{}' > "$TMP_BAD/.claude/HARNESS.json"
touch "$TMP_BAD/AGENTS.md"
mode=$(classify_mode "$TMP_BAD")
[ "$mode" = "legacy" ] && pass "scenario legacy: empty manifest" || fail "scenario legacy: empty manifest (got: $mode)"
rm -rf "$TMP_BAD"

# ── 5. fresh 우선순위 확인: HARNESS.json 도 없고 흔적도 없음 ──
TMP_EMPTY="$(mktemp -d)"
mode=$(classify_mode "$TMP_EMPTY")
[ "$mode" = "fresh" ] && pass "scenario fresh: empty dir" || fail "scenario fresh: empty dir (got: $mode)"
rm -rf "$TMP_EMPTY"

# ── 6. trace 가 .claude/skills/ehr-* 인 경우도 legacy 로 잡히는지 ──
TMP_SKILLS="$(mktemp -d)"
mkdir -p "$TMP_SKILLS/.claude/skills/ehr-screen-builder"
touch "$TMP_SKILLS/.claude/skills/ehr-screen-builder/SKILL.md"
mode=$(classify_mode "$TMP_SKILLS")
[ "$mode" = "legacy" ] && pass "scenario legacy: skills only" || fail "scenario legacy: skills only (got: $mode)"
rm -rf "$TMP_SKILLS"

echo "ALL SCENARIO TESTS PASSED"
