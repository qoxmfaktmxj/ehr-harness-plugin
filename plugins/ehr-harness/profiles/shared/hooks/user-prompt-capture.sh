#!/usr/bin/env bash
# UserPromptSubmit hook — correction/success heuristic capture.
# 가드 1: stdout = 0 byte (모든 경로에서 stdout 침묵).
set +e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# stderr 로 모든 stdout 리다이렉트 (가드 1)
exec 3>&1 1>&2

silent_exit() { exec 1>&3 3>&-; exit 0; }

# 의존성 검사 — node 만 필요 (jq 안 씀)
command -v node >/dev/null 2>&1 || silent_exit

# stdin JSON 읽기 (Claude Code hook spec)
INPUT="$(cat)"
[ -n "$INPUT" ] || silent_exit

# JSON 파싱 (node)
PROMPT=$(MFP="$INPUT" node -e "
  try { const j=JSON.parse(process.env.MFP); process.stdout.write(j.prompt || ''); }
  catch(e) {}
" 2>/dev/null)
SESSION_ID=$(MFP="$INPUT" node -e "
  try { const j=JSON.parse(process.env.MFP); process.stdout.write(j.session_id || ''); }
  catch(e) {}
" 2>/dev/null)
TRANSCRIPT=$(MFP="$INPUT" node -e "
  try { const j=JSON.parse(process.env.MFP); process.stdout.write(j.transcript_path || ''); }
  catch(e) {}
" 2>/dev/null)

[ -n "$PROMPT" ] || silent_exit

# lib 로드 — generated path: $CLAUDE_PROJECT_DIR/.claude/...
# 플러그인 source path: $CLAUDE_PLUGIN_ROOT/skills/ehr-harness/lib/
LIB=""
# 이 파일 위치: profiles/shared/hooks/ → ehr-harness/skills/ehr-harness/lib 까지 ../../../
HOOK_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for cand in \
  "${CLAUDE_PLUGIN_ROOT:-}/skills/ehr-harness/lib" \
  "$PROJECT_DIR/.claude/skills/ehr-harness/lib" \
  "$HOOK_SELF/../../../skills/ehr-harness/lib"; do
  if [ -n "$cand" ] && [ -f "$cand/learnings.sh" ]; then LIB="$cand"; break; fi
done
[ -n "$LIB" ] || silent_exit

# shellcheck disable=SC1091
. "$LIB/learnings.sh" 2>/dev/null || silent_exit
# shellcheck disable=SC1091
. "$LIB/redaction.sh" 2>/dev/null || silent_exit

# pre-flight (capture_enabled, gitignore 강제)
ehr_learn_should_capture || silent_exit

# 분류
KIND=$(ehr_classify_signal "$PROMPT")
[ "$KIND" = "none" ] && silent_exit

SCORE=$(ehr_score_for_kind "$KIND")

# transcript 마지막 assistant 턴 1개 (있으면) — 200자 trim
PREV_TURN=""
if [ -f "$TRANSCRIPT" ]; then
  PREV_TURN=$(grep -E '"role":\s*"assistant"' "$TRANSCRIPT" 2>/dev/null \
              | tail -1 \
              | MFP_LINE="$(cat)" node -e "
                  try { const j=JSON.parse(process.env.MFP_LINE); process.stdout.write(String(j.content||'').slice(0,400)); }
                  catch(e) {}
                " 2>/dev/null \
              | head -c 400)
fi

# redaction
PROMPT_RED=$(ehr_redact "$(printf '%s' "$PROMPT" | head -c 200)")
PREV_RED=$(ehr_redact "$(printf '%s' "$PREV_TURN" | head -c 200)")
META=$(ehr_redact_meta "$PROMPT")

# drop?
DROP=$(ehr_redact_should_drop "$META")
[ "$DROP" = "true" ] && silent_exit

# session/snippet hash (redacted 기반)
SESSION_HASH="sha256:$(printf '%s' "$SESSION_ID" | sha256sum 2>/dev/null | awk '{print $1}')"
SNIPPET_HASH="sha256:$(printf '%s%s' "$PROMPT_RED" "$PREV_RED" | sha256sum 2>/dev/null | awk '{print $1}')"

# profile (HARNESS 에서 — node)
PROFILE=$(MFP="$PROJECT_DIR/.claude/HARNESS.json" node -e "
  try {
    const m = JSON.parse(require('fs').readFileSync(process.env.MFP, 'utf8'));
    process.stdout.write(m.profile || 'ehr5');
  } catch(e) { process.stdout.write('ehr5'); }
" 2>/dev/null)

TS=$(date -Iseconds 2>/dev/null || date)

# record 조립 (node)
RECORD=$(
  TS="$TS" SH="$SESSION_HASH" KIND="$KIND" SCORE="$SCORE" \
  PR="$PROMPT_RED" PV="$PREV_RED" SNH="$SNIPPET_HASH" META_JSON="$META" PROFILE="$PROFILE" \
  node -e "
    const e=process.env;
    const meta=JSON.parse(e.META_JSON);
    const rec={
      schema_version: 1,
      ts: e.TS,
      session_hash: e.SH,
      kind: e.KIND,
      score_delta: parseInt(e.SCORE, 10),
      prompt_snippet_redacted: e.PR,
      prev_turn_snippet_redacted: e.PV,
      snippet_hash: e.SNH,
      redaction_checked: meta.redaction_checked,
      redaction_count: meta.redaction_count,
      redaction_failed: meta.redaction_failed,
      sensitivity: (meta.redaction_count > 0 ? 'possible_pii' : 'low'),
      candidate_rule: null,
      tool_context: {},
      profile: e.PROFILE
    };
    process.stdout.write(JSON.stringify(rec));
  " 2>/dev/null)

[ -n "$RECORD" ] && ehr_learn_append "$RECORD" 2>/dev/null
silent_exit
