#!/usr/bin/env bash
# PII redaction library.
# 정규식 기반: 사번 [ID], 한글 이름+직책 [NAME], 날짜 [DATE], 조직코드 [ORG].
# 한국 EHR/HR 도메인 특화. v1.11+ 에서 외부 라이브러리 교체 가능.
#
# 주의: sed의 한글 처리를 위해 LANG=ko_KR.UTF-8 을 명시한다.
#   Git Bash (Windows) 의 기본 LANG="" 환경에서는 [가-힣] 범위가 바이트 단위로
#   처리되어 치환이 잘못될 수 있다.

# === 공개 함수 ===

# ehr_redact: 입력 텍스트의 PII 를 [TAG] 로 치환.
ehr_redact() {
  local s="$1"
  # 순서: ORG → DATE → NAME → ID (덜 specific 한 ID 를 마지막에)

  # 조직코드: TBL_ prefix 포함/미포함 HR 코드
  s=$(printf '%s' "$s" | LANG=ko_KR.UTF-8 sed -E \
    's/(TBL_)?(THRM[0-9]+|HRM[0-9]+|CPN[0-9]+|TIM[0-9]+|EDU[0-9]+|LF[0-9]+)(_[A-Z]+)?/[ORG]/g')

  # 날짜: YYYY-MM-DD, YYYY/MM/DD, ISO 8601 (T 이하 시분초 포함)
  s=$(printf '%s' "$s" | LANG=ko_KR.UTF-8 sed -E \
    's/([0-9]{4}[-\/][0-9]{1,2}[-\/][0-9]{1,2}(T[0-9:]+)?)/[DATE]/g')

  # 한글 이름 (2~4자) + 직책 (선택 공백 포함)
  s=$(printf '%s' "$s" | LANG=ko_KR.UTF-8 sed -E \
    's/([가-힣]{2,4})[ ]?(님|책임|수석|선임|대리|과장|차장|부장|팀장|매니저|연구원|전문위원)/[NAME]/g')

  # 사번: 5~8자리 연속 숫자 (전후 non-alnum boundary 보존)
  # \1, \3 으로 boundary 문자 복원
  s=$(printf '%s' "$s" | LANG=ko_KR.UTF-8 sed -E \
    's/(^|[^0-9A-Za-z가-힣])([0-9]{5,8})([^0-9A-Za-z가-힣]|$)/\1[ID]\3/g')

  printf '%s' "$s"
}

# ehr_redact_meta: redaction 결과 메타데이터 JSON.
# Output: {"redaction_checked": true, "redaction_count": N, "redaction_failed": false}
ehr_redact_meta() {
  local input="$1"
  local out
  if ! out=$(ehr_redact "$input" 2>/dev/null); then
    printf '{"redaction_checked":true,"redaction_count":0,"redaction_failed":true}'
    return 0
  fi
  local count
  count=$(printf '%s\n' "$out" | grep -oE '\[(ID|NAME|DATE|ORG)\]' | wc -l | tr -d ' ')
  printf '{"redaction_checked":true,"redaction_count":%s,"redaction_failed":false}' "$count"
}

# ehr_redact_should_drop: 메타 JSON 받아 drop 여부 (echo true/false).
# Drop 조건: redaction_checked != true OR redaction_failed == true.
# (redaction_count == 0 인 정상 record 는 유지)
ehr_redact_should_drop() {
  local meta="$1"
  local checked failed
  checked=$(MFP="$meta" node -e "
    try { console.log(JSON.parse(process.env.MFP).redaction_checked === true ? 'true' : 'false'); }
    catch (e) { console.log('false'); }
  " 2>/dev/null)
  failed=$(MFP="$meta" node -e "
    try { console.log(JSON.parse(process.env.MFP).redaction_failed === true ? 'true' : 'false'); }
    catch (e) { console.log('true'); }
  " 2>/dev/null)
  if [ "$checked" != "true" ] || [ "$failed" = "true" ]; then
    echo true
  else
    echo false
  fi
}
