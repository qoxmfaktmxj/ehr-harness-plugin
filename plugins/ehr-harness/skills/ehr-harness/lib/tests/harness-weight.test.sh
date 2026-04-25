#!/usr/bin/env bash
# 경량 가드 8종 종합 검증.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

PASS=0; FAIL_CNT=0
pass() { PASS=$((PASS+1)); }
fail() { FAIL_CNT=$((FAIL_CNT+1)); echo "FAIL: $1"; exit 1; }
ok_le() { if [ "$1" -le "$2" ]; then pass; else fail "$1 > $2 ($3)"; fi; }
ok_eq() { if [ "$1" = "$2" ]; then pass; else fail "expected [$2] got [$1] ($3)"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# === Guard 1: UserPromptSubmit hook stdout = 0 byte ===
mkdir -p "$TMP/.claude"
echo '{"schema_version":5,"profile":"ehr4","ehr_cycle":{"learnings_meta":{"capture_enabled":true}}}' > "$TMP/.claude/HARNESS.json"
echo '.claude/learnings/' > "$TMP/.gitignore"

input='{"prompt":"좋아 진행","session_id":"w1","transcript_path":"/dev/null"}'
b1=$(CLAUDE_PROJECT_DIR="$TMP" bash "$PLUGIN_ROOT/profiles/shared/hooks/user-prompt-capture.sh" \
  <<<"$input" | wc -c | tr -d ' ')
ok_eq "$b1" "0" "Guard 1: UserPromptSubmit stdout=0"

# === Guard 2: SessionStart stdout ≤ 1024 + valid JSON ===
ENVF="$TMP/env_inj"
: > "$ENVF"
out=$(CLAUDE_PROJECT_DIR="$TMP" CLAUDE_ENV_FILE="$ENVF" \
  bash "$PLUGIN_ROOT/profiles/shared/hooks/session-start-inject.sh" </dev/null)
b2=$(printf '%s' "$out" | wc -c | tr -d ' ')
ok_le "$b2" "1024" "Guard 2: SessionStart ≤ 1024"
if [ "$b2" -gt 0 ]; then
  if MFP="$out" node -e "
    try { JSON.parse(process.env.MFP); process.exit(0); }
    catch(e) { process.exit(1); }
  " 2>/dev/null; then pass; else fail "Guard 2: invalid JSON"; fi
fi

# === Guard 3: AGENTS.md.skel EHR-LESSONS 섹션 ≤ 1024 byte ===
for prof in ehr4 ehr5; do
  skel="$PLUGIN_ROOT/profiles/$prof/skeleton/AGENTS.md.skel"
  s=$(awk '/<!-- EHR-LESSONS:BEGIN/,/<!-- EHR-LESSONS:END/' "$skel" | wc -c | tr -d ' ')
  ok_le "$s" "1024" "Guard 3: $prof AGENTS.md.skel EHR-LESSONS section ≤ 1024 (got $s)"
done

# === Guard 4: ehr-lessons/SKILL.md ≤ 15360 byte (per profile) ===
# 주의: ehr-harness/SKILL.md (메타스킬) 는 본 가드 적용 외 — 별도 정책
for prof in ehr4 ehr5; do
  f="$PLUGIN_ROOT/profiles/$prof/skills/ehr-lessons/SKILL.md"
  if [ -f "$f" ]; then
    s=$(wc -c < "$f" | tr -d ' ')
    ok_le "$s" "15360" "Guard 4: $prof ehr-lessons/SKILL.md ≤ 15360 (got $s)"
  else
    fail "Guard 4: $f 없음"
  fi
done

# === Guard 5: merge.sh apply_staged 무권한 → exit 2 ===
( cd "$TMP" && bash "$PLUGIN_ROOT/skills/ehr-harness/lib/merge.sh" \
    apply_staged /tmp/nonexistent.md ) >/dev/null 2>&1
ec=$?
ok_eq "$ec" "2" "Guard 5: no EHR_AUDIT_APPROVED → exit 2"

# === Guard 6: v4→v5 strict-append (회귀 위임) ===
if bash "$PLUGIN_ROOT/skills/ehr-harness/lib/harness-state.test.sh" >/dev/null 2>&1; then
  pass
else
  fail "Guard 6: harness-state.test.sh 실패"
fi

# === Guard 7: redaction drop (회귀 위임) ===
if bash "$PLUGIN_ROOT/skills/ehr-harness/lib/redaction.test.sh" >/dev/null 2>&1; then
  pass
else
  fail "Guard 7: redaction.test.sh 실패"
fi

# === Guard 8: plugin-dev scope 격리 (org-template reserved) ===
mkdir -p "$TMP/.claude/learnings/staged"
cat > "$TMP/.claude/learnings/staged/g8.md" <<'EOF'
---
topic: g8
score: 4
scope: org-template
target: AGENTS.md
---
EOF
echo '{"schema_version":5,"profile":"ehr4","ehr_cycle":{"learnings_meta":{"staged_nonces":{}}}}' > "$TMP/.claude/HARNESS.json"
NONCE=$(sha256sum "$TMP/.claude/learnings/staged/g8.md" | awk '{print $1}')
HFP="$TMP/.claude/HARNESS.json" NONCE="$NONCE" node -e "
  const fs=require('fs');
  const m=JSON.parse(fs.readFileSync(process.env.HFP,'utf8'));
  m.ehr_cycle.learnings_meta.staged_nonces['g8']=process.env.NONCE;
  fs.writeFileSync(process.env.HFP, JSON.stringify(m, null, 2));
"
( cd "$TMP" && EHR_AUDIT_APPROVED=1 EHR_NONCE="$NONCE" \
    bash "$PLUGIN_ROOT/skills/ehr-harness/lib/merge.sh" \
    apply_staged ".claude/learnings/staged/g8.md" ) >/dev/null 2>&1
ec=$?
ok_eq "$ec" "5" "Guard 8: org-template scope reserved → exit 5"

echo "ALL WEIGHT GUARD TESTS PASSED  pass=$PASS fail=$FAIL_CNT"
[ "$FAIL_CNT" -eq 0 ]
