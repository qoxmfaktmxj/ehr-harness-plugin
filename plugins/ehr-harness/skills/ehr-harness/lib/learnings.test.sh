#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR"
FIXTURES="$LIB_DIR/fixtures"

# shellcheck disable=SC1091
. "$LIB_DIR/learnings.sh"

PASS=0; FAIL_CNT=0
pass() { PASS=$((PASS+1)); }
fail() { FAIL_CNT=$((FAIL_CNT+1)); echo "FAIL: $1"; exit 1; }

# === ehr_classify_signal — fixture 기반 ===
classify_one() {
  local file="$1" expected input kind
  while IFS=$'\t' read -r expected input; do
    case "$expected" in ''|'#'*) continue ;; esac
    kind=$(ehr_classify_signal "$input")
    [ "$kind" = "$expected" ] && pass || fail "classify [$input] expected=$expected got=$kind"
  done < "$file"
}
classify_one "$FIXTURES/prompts-ko.txt"
classify_one "$FIXTURES/prompts-en.txt"

# excluded — 모두 'none' 이어야 함
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  kind=$(ehr_classify_signal "$line")
  [ "$kind" = "none" ] && pass || fail "excluded [$line] got=$kind"
done < "$FIXTURES/prompts-excluded.txt"

# === score 계산 ===
[ "$(ehr_score_for_kind success)" = "2" ] && pass || fail "score success"
[ "$(ehr_score_for_kind correction)" = "1" ] && pass || fail "score correction"
[ "$(ehr_score_for_kind none)" = "0" ] && pass || fail "score none"

# === ehr_learn_should_capture ===
TMP="$(mktemp -d)"
mkdir -p "$TMP/.claude"
echo '{"schema_version":5,"ehr_cycle":{"learnings_meta":{"capture_enabled":true}}}' > "$TMP/.claude/HARNESS.json"
echo '.claude/learnings/' > "$TMP/.gitignore"

(
  export CLAUDE_PROJECT_DIR="$TMP"
  if ehr_learn_should_capture; then echo yes; else echo no; fi
) > "$TMP/_out"
[ "$(cat "$TMP/_out")" = "yes" ] && pass || fail "should_capture ok"

# gitignore 미적용 → 거부 + degraded flag
rm "$TMP/.gitignore"
(
  export CLAUDE_PROJECT_DIR="$TMP"
  if ehr_learn_should_capture; then echo yes; else echo no; fi
) > "$TMP/_out2"
[ "$(cat "$TMP/_out2")" = "no" ] && pass || fail "should_capture refuse no-gitignore"
[ -f "$TMP/.claude/.ehr-hook-degraded.flag" ] && pass || fail "degraded flag created"

# capture_enabled=false → 거부
echo '.claude/learnings/' > "$TMP/.gitignore"
echo '{"schema_version":5,"ehr_cycle":{"learnings_meta":{"capture_enabled":false}}}' > "$TMP/.claude/HARNESS.json"
(
  export CLAUDE_PROJECT_DIR="$TMP"
  if ehr_learn_should_capture; then echo yes; else echo no; fi
) > "$TMP/_out3"
[ "$(cat "$TMP/_out3")" = "no" ] && pass || fail "capture_enabled=false refused"

# === ehr_learn_append ===
echo '{"schema_version":5,"ehr_cycle":{"learnings_meta":{"capture_enabled":true}}}' > "$TMP/.claude/HARNESS.json"
(
  export CLAUDE_PROJECT_DIR="$TMP"
  ehr_learn_append '{"ts":"2026-04-25T10:00:00+09:00","kind":"success","score_delta":2}'
)
[ -f "$TMP/.claude/learnings/pending.jsonl" ] && pass || fail "pending.jsonl created"
lines=$(wc -l < "$TMP/.claude/learnings/pending.jsonl")
[ "$lines" -ge 1 ] && pass || fail "pending has line"

rm -rf "$TMP"
echo "ALL LEARNINGS TESTS PASSED  pass=$PASS fail=$FAIL_CNT"
[ "$FAIL_CNT" -eq 0 ]
