#!/usr/bin/env bash
# Self-evolving learnings library.
# - ehr_classify_signal: heuristic 매칭 (한국어 + 영어, POSIX boundary 대안)
# - ehr_score_for_kind: success=2 / correction=1 / none=0
# - ehr_learn_should_capture: gitignore 강제 + capture_enabled 검사 (node 기반)
# - ehr_learn_append: pending.jsonl append

# === 어휘 ===
# 한국어 boundary 대안: 한국어 어절은 조사 붙음이 자연스러우므로
# left boundary 만 체크 (우측은 조사/어미가 바로 이어질 수 있음)
KO_BOUND='(^|[^가-힣A-Za-z0-9])'

EHR_LEX_SUCCESS_KO='(좋아|딱 그거|이 방향|확정|좋습니다|맞아|정확|완벽|됐어|이 방식)'
EHR_LEX_CORR_KO='(아니|다시|그거 말고|수정해줘|고쳐|잘못|틀렸|되돌려|롤백|빼고|없애|아니라고)'
EHR_LEX_SUCCESS_EN='(perfect|exactly|confirmed|looks right|ship it|lgtm|good[, ])'
EHR_LEX_CORR_EN='(no[,. ]|undo|revert|wrong|that.s not|nope|go back|cancel)'

# === 공개 함수 ===

# ehr_classify_signal: 입력 prompt 분류. 출력: success | correction | none
# 길이 임계는 byte 단위로 측정한다 — bash ${#var} 는 locale 의존이라
# Windows Git-bash 환경에 따라 character/byte 가 갈려 분류가 비결정적이 된다.
ehr_classify_signal() {
  local s="$1"
  local len; len=$(printf '%s' "$s" | wc -c | tr -d ' ')
  # 제외 1: 길이 < 3 byte
  if [ "$len" -lt 3 ]; then echo none; return 0; fi
  # 제외 2: 길이 > 500 byte (한글 약 165자)
  if [ "$len" -gt 500 ]; then echo none; return 0; fi
  # 제외 3: 순수 URL
  if printf '%s' "$s" | grep -qE '^https?://[^ ]+$'; then echo none; return 0; fi
  # 제외 4: 순수 git/shell 명령
  if printf '%s' "$s" | grep -qE '^(git|cd|ls|cat|grep|rm|cp|mv|find) '; then echo none; return 0; fi

  # success 우선 (둘 다 매칭되면 success — 양성 신호 우대)
  if LANG=ko_KR.UTF-8 printf '%s' "$s" | grep -qE "${KO_BOUND}${EHR_LEX_SUCCESS_KO}" \
     || printf '%s' "$s" | grep -qiE "${EHR_LEX_SUCCESS_EN}"; then
    echo success; return 0
  fi

  if LANG=ko_KR.UTF-8 printf '%s' "$s" | grep -qE "${KO_BOUND}${EHR_LEX_CORR_KO}" \
     || printf '%s' "$s" | grep -qiE "${EHR_LEX_CORR_EN}"; then
    echo correction; return 0
  fi

  echo none
}

ehr_score_for_kind() {
  case "$1" in
    success)    echo 2 ;;
    correction) echo 1 ;;
    *)          echo 0 ;;
  esac
}

# ehr_learn_should_capture: capture pre-flight
# 0 = 진행, 1 = silent skip
ehr_learn_should_capture() {
  local proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  local harness="$proj/.claude/HARNESS.json"
  local gi="$proj/.gitignore"
  local flag="$proj/.claude/.ehr-hook-degraded.flag"

  [ -f "$harness" ] || return 1

  # capture_enabled 확인 (node 기반)
  local enabled
  enabled=$(MFP="$harness" node -e "
    try {
      const m = JSON.parse(require('fs').readFileSync(process.env.MFP, 'utf8'));
      const v = m && m.ehr_cycle && m.ehr_cycle.learnings_meta && m.ehr_cycle.learnings_meta.capture_enabled;
      console.log(v === false ? 'false' : 'true');  // default true
    } catch(e) { console.log('false'); }
  " 2>/dev/null)
  [ "$enabled" = "true" ] || return 1

  # gitignore 강제
  if [ -f "$gi" ] && grep -qE '^\.claude/learnings/' "$gi"; then
    :
  else
    mkdir -p "$proj/.claude" 2>/dev/null
    : > "$flag"
    return 1
  fi

  return 0
}

# ehr_learn_append: pending.jsonl append. 호출자가 redaction 완료 JSON 라인 전달.
ehr_learn_append() {
  local proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  local pending="$proj/.claude/learnings/pending.jsonl"
  local rec="$1"
  mkdir -p "$(dirname "$pending")" 2>/dev/null || return 1
  printf '%s\n' "$rec" >> "$pending" || return 1
  return 0
}
