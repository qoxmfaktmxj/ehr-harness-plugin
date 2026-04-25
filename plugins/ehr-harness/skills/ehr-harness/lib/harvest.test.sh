#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR"
FIXTURES="$LIB_DIR/fixtures"

# shellcheck disable=SC1091
. "$LIB_DIR/harvest.sh"

PASS=0; FAIL_CNT=0
pass() { PASS=$((PASS+1)); }
fail() { FAIL_CNT=$((FAIL_CNT+1)); echo "FAIL: $1"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# === 점수 계산 ===
# success×1 + correction×2 = 4
[ "$(ehr_harvest_score 1 2)" = "4" ] && pass || fail "score(1,2) expected 4"
[ "$(ehr_harvest_score 0 0)" = "0" ] && pass || fail "score(0,0) expected 0"
[ "$(ehr_harvest_score 2 1)" = "5" ] && pass || fail "score(2,1) expected 5"

# === distinct_sessions ===
ds=$(ehr_harvest_distinct_sessions "$FIXTURES/learnings/pending-5signals.jsonl")
[ "$ds" -ge 3 ] && pass || fail "distinct_sessions ≥ 3, got=$ds"

ds_empty=$(ehr_harvest_distinct_sessions /dev/null)
[ "$ds_empty" = "0" ] && pass || fail "distinct on /dev/null = 0, got=$ds_empty"

# === corrupt line skip ===
valid=$(ehr_harvest_count_valid "$FIXTURES/learnings/pending-corrupt-line.jsonl")
[ "$valid" = "3" ] && pass || fail "valid lines skip corrupt expected=3 got=$valid"

# === LLM cap ===
yes '{"schema_version":1,"ts":"2026-04-21T10:00:00+09:00","kind":"correction","score_delta":1}' \
  | head -150 > "$TMP/big.jsonl"
capped=$(ehr_harvest_take_first "$TMP/big.jsonl" 100 | wc -l | tr -d ' ')
[ "$capped" = "100" ] && pass || fail "cap to 100, got=$capped"

# === nonce 형식 ===
echo "test content" > "$TMP/staged-test.md"
nonce=$(ehr_harvest_nonce "$TMP/staged-test.md")
printf '%s' "$nonce" | grep -qE '^[a-f0-9]{64}$' && pass || fail "nonce format ^[a-f0-9]{64}$, got=$nonce"

# 빈 파일에 대한 nonce 도 64 hex
: > "$TMP/empty.md"
nonce_empty=$(ehr_harvest_nonce "$TMP/empty.md")
printf '%s' "$nonce_empty" | grep -qE '^[a-f0-9]{64}$' && pass || fail "empty nonce format, got=$nonce_empty"

# === sessions count: 동일 session 중복은 unique 하게 카운트 ===
cat > "$TMP/dup_session.jsonl" <<'EOF'
{"session_hash":"sha256:a","kind":"success","score_delta":2}
{"session_hash":"sha256:a","kind":"correction","score_delta":1}
{"session_hash":"sha256:b","kind":"success","score_delta":2}
EOF
ds_dup=$(ehr_harvest_distinct_sessions "$TMP/dup_session.jsonl")
[ "$ds_dup" = "2" ] && pass || fail "distinct dedupe, expected=2 got=$ds_dup"

echo "ALL HARVEST TESTS PASSED  pass=$PASS fail=$FAIL_CNT"
[ "$FAIL_CNT" -eq 0 ]
