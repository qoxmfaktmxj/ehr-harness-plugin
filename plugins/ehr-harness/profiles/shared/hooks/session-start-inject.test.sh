#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/session-start-inject.sh"

PASS=0; FAIL_CNT=0
pass() { PASS=$((PASS+1)); }
fail() { FAIL_CNT=$((FAIL_CNT+1)); echo "FAIL: $1"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.claude"

# preferences_history 가 있는 v5 HARNESS
cat > "$TMP/.claude/HARNESS.json" <<'JSON'
{
  "schema_version": 5,
  "profile": "ehr4",
  "ehr_cycle": {
    "preferences_history": [
      {"ts":"2026-04-20T10:00:00+09:00","key":"SUGGEST_MODE","from":"ask","to":"silent"},
      {"ts":"2026-04-21T10:00:00+09:00","key":"DB_AUTH","from":"full","to":"readonly"},
      {"ts":"2026-04-22T10:00:00+09:00","key":"RESPONSE_TONE","from":"verbose","to":"concise"},
      {"ts":"2026-04-23T10:00:00+09:00","key":"LANG","from":"ko","to":"ko"}
    ],
    "learnings_meta": {"capture_enabled": true}
  }
}
JSON

ENVF="$TMP/env_inject"
: > "$ENVF"

# === 가드 2: stdout ≤ 1024 byte JSON ===
out=$(CLAUDE_PROJECT_DIR="$TMP" CLAUDE_ENV_FILE="$ENVF" bash "$HOOK" </dev/null)
out_bytes=$(printf '%s' "$out" | wc -c | tr -d ' ')
[ "$out_bytes" -le 1024 ] && pass || fail "stdout ≤ 1024 (got $out_bytes)"

# JSON valid (node)
if [ "$out_bytes" -gt 0 ]; then
  if MFP_LINE="$out" node -e "
    try { JSON.parse(process.env.MFP_LINE); process.exit(0); }
    catch(e) { process.exit(1); }
  "; then pass; else fail "stdout is not valid JSON"; fi

  # additionalContext 키 존재
  ctx=$(MFP="$out" node -e "
    try { console.log(JSON.parse(process.env.MFP).hookSpecificOutput.additionalContext || ''); }
    catch(e) {}
  ")
  [ -n "$ctx" ] && pass || fail "additionalContext missing"
  printf '%s' "$ctx" | grep -q "DB" && pass || fail "ctx missing DB"
fi

# === CLAUDE_ENV_FILE 에 export 라인 기록 ===
grep -q '^export EHR_DB_AUTH=' "$ENVF" && pass || fail "env file missing DB_AUTH"
grep -q '^export EHR_FILE_SCOPE=' "$ENVF" && pass || fail "env file missing FILE_SCOPE"

# === HARNESS.json 부재 → silent skip ===
rm "$TMP/.claude/HARNESS.json"
out3=$(CLAUDE_PROJECT_DIR="$TMP" CLAUDE_ENV_FILE="$ENVF" bash "$HOOK" </dev/null)
b3=$(printf '%s' "$out3" | wc -c | tr -d ' ')
[ "$b3" = "0" ] && pass || fail "stdout 0 when no HARNESS (got $b3)"

# === node 미설치 시 silent — 시뮬은 PATH 에서 node 제거 ===
PATH_NONODE="$(printf '%s' "$PATH" | tr ':' '\n' | grep -viE '/(nodejs|node)' | paste -sd: -)"
if [ -n "$PATH_NONODE" ]; then
  echo '{"schema_version":5,"profile":"ehr4","ehr_cycle":{"preferences_history":[{"ts":"2026","key":"DB_AUTH","from":"full","to":"readonly"}]}}' > "$TMP/.claude/HARNESS.json"
  out_nonode=$(PATH="$PATH_NONODE" CLAUDE_PROJECT_DIR="$TMP" CLAUDE_ENV_FILE="$ENVF" bash "$HOOK" </dev/null)
  b_nonode=$(printf '%s' "$out_nonode" | wc -c | tr -d ' ')
  [ "$b_nonode" = "0" ] && pass || fail "stdout 0 when no node (got $b_nonode)"
fi

echo "ALL SESSION-START INJECT TESTS PASSED  pass=$PASS fail=$FAIL_CNT"
[ "$FAIL_CNT" -eq 0 ]
