#!/usr/bin/env bash
# SessionStart hook — preferences inject.
# 가드 2: stdout ≤ 1024 byte JSON (node JSON.parse 통과 필수).
# - tool-visible: $CLAUDE_ENV_FILE 에 export 라인
# - model-visible: hookSpecificOutput.additionalContext (≤1KB)
# node 없으면 env 만, stdout 0.
set +e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
HARNESS="$PROJECT_DIR/.claude/HARNESS.json"

[ -f "$HARNESS" ] || exit 0

# preferences_history 의 최신 key 별 to 값 추출 (allowlist 6개)
get_pref() {
  local key="$1" default="$2"
  command -v node >/dev/null 2>&1 || { printf '%s' "$default"; return; }
  local v
  v=$(MFP="$HARNESS" KEY="$key" node -e "
    try {
      const m = JSON.parse(require('fs').readFileSync(process.env.MFP, 'utf8'));
      const hist = (m && m.ehr_cycle && m.ehr_cycle.preferences_history) || [];
      const matches = hist.filter(h => h && h.key === process.env.KEY);
      if (matches.length > 0) process.stdout.write(String(matches[matches.length - 1].to || ''));
    } catch(e) {}
  " 2>/dev/null)
  [ -z "$v" ] && v="$default"
  printf '%s' "$v"
}

SUGGEST_MODE=$(get_pref SUGGEST_MODE ask)
RESPONSE_TONE=$(get_pref RESPONSE_TONE concise)
DB_AUTH=$(get_pref DB_AUTH full)
FILE_SCOPE=$(get_pref FILE_SCOPE minimal)
LANG_PREF=$(get_pref LANG ko)
HARVEST_POLICY=$(get_pref HARVEST_POLICY manual_only)

# (1) tool-visible — CLAUDE_ENV_FILE
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    printf 'export EHR_DB_AUTH=%q\n'         "$DB_AUTH"
    printf 'export EHR_FILE_SCOPE=%q\n'      "$FILE_SCOPE"
    printf 'export EHR_HARVEST_POLICY=%q\n'  "$HARVEST_POLICY"
  } >> "$CLAUDE_ENV_FILE" 2>/dev/null
fi

# (2) model-visible — additionalContext JSON
# node 없으면 silent (env 만)
command -v node >/dev/null 2>&1 || exit 0

MAX_CTX=700  # JSON 오버헤드 여유
CTX_RAW="EHR harness preferences: 응답 톤=${RESPONSE_TONE}, 언어=${LANG_PREF}, 제안 모드=${SUGGEST_MODE}, DB 권한=${DB_AUTH}, 파일 스코프=${FILE_SCOPE}, harvest=${HARVEST_POLICY}"

# byte-safe 축약 (UTF-8 안전 — 문자열만 길이 줄임, JSON 은 마지막에 생성)
CTX=$(printf '%s' "$CTX_RAW" | awk -v max="$MAX_CTX" '
  { s=$0; while (length(s) > max) s=substr(s, 1, length(s)-1); print s }
')

# JSON 조립
JSON=$(MFP_CTX="$CTX" node -e "
  const ctx = process.env.MFP_CTX || '';
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'SessionStart',
      additionalContext: ctx
    }
  }));
" 2>/dev/null)

# 가드 2: 1024 + JSON valid
SIZE=$(printf '%s' "$JSON" | wc -c | tr -d ' ')
if [ "$SIZE" -le 1024 ]; then
  if MFP="$JSON" node -e "
    try { JSON.parse(process.env.MFP); process.exit(0); }
    catch(e) { process.exit(1); }
  " 2>/dev/null; then
    printf '%s' "$JSON"
  fi
fi
exit 0
