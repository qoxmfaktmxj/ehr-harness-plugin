#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/user-prompt-capture.sh"

PASS=0; FAIL_CNT=0
pass() { PASS=$((PASS+1)); }
fail() { FAIL_CNT=$((FAIL_CNT+1)); echo "FAIL: $1"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.claude"
echo '{"schema_version":5,"profile":"ehr4","ehr_cycle":{"learnings_meta":{"capture_enabled":true}}}' > "$TMP/.claude/HARNESS.json"
echo '.claude/learnings/' > "$TMP/.gitignore"

# === 가드 1: stdout = 0 byte (success signal) ===
input='{"prompt":"좋아 이 방향으로 확정","transcript_path":"/dev/null","session_id":"test1"}'
out_bytes=$(CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$input" | wc -c | tr -d ' ')
[ "$out_bytes" = "0" ] && pass || fail "stdout 0 byte (success), got=$out_bytes"

# pending.jsonl record 존재 + redacted/checked
[ -f "$TMP/.claude/learnings/pending.jsonl" ] && pass || fail "pending.jsonl created"

# kind 검증 (node 로 첫 줄 파싱)
kind=$(MFP="$TMP/.claude/learnings/pending.jsonl" node -e "
  const fs=require('fs');
  const lines=fs.readFileSync(process.env.MFP,'utf8').trim().split('\n');
  console.log(JSON.parse(lines[0]).kind);
")
[ "$kind" = "success" ] && pass || fail "kind=$kind expected=success"

redact_chk=$(MFP="$TMP/.claude/learnings/pending.jsonl" node -e "
  const fs=require('fs');
  const lines=fs.readFileSync(process.env.MFP,'utf8').trim().split('\n');
  console.log(JSON.parse(lines[0]).redaction_checked);
")
[ "$redact_chk" = "true" ] && pass || fail "redaction_checked=$redact_chk"

# === none 신호는 append 안 함 ===
rm -f "$TMP/.claude/learnings/pending.jsonl"
input2='{"prompt":"JSP 파일 위치 알려줘","transcript_path":"/dev/null","session_id":"test2"}'
CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$input2" >/dev/null
[ ! -f "$TMP/.claude/learnings/pending.jsonl" ] && pass || fail "no append for kind=none"

# === gitignore 미적용 → silent skip + degraded flag ===
rm -f "$TMP/.gitignore"
input3='{"prompt":"좋아 진행","transcript_path":"/dev/null","session_id":"test3"}'
CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$input3" >/dev/null
ec=$?
[ "$ec" = "0" ] && pass || fail "exit 0 even when refused, got=$ec"
[ -f "$TMP/.claude/.ehr-hook-degraded.flag" ] && pass || fail "degraded flag set"

# === HARNESS.json 부재 → silent exit 0 ===
rm -f "$TMP/.claude/HARNESS.json"
echo '.claude/learnings/' > "$TMP/.gitignore"
CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$input" >/dev/null
ec2=$?
[ "$ec2" = "0" ] && pass || fail "exit 0 when no HARNESS.json, got=$ec2"

echo "ALL CAPTURE HOOK TESTS PASSED  pass=$PASS fail=$FAIL_CNT"
[ "$FAIL_CNT" -eq 0 ]
