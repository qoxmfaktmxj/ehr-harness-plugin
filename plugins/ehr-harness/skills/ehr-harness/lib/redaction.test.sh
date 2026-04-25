#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR"
FIXTURES="$LIB_DIR/fixtures"

# shellcheck disable=SC1091
. "$LIB_DIR/redaction.sh"

PASS=0; FAIL_CNT=0
pass() { PASS=$((PASS+1)); }
fail() { FAIL_CNT=$((FAIL_CNT+1)); echo "FAIL: $1"; exit 1; }

# === ehr_redact / ehr_redact_meta fixture-driven ===
while IFS=$'\t' read -r expected_count input expected_pattern; do
  case "$expected_count" in ''|'#'*) continue ;; esac
  out=$(ehr_redact "$input")
  cnt=$(printf '%s\n' "$out" | grep -oE '\[(ID|NAME|DATE|ORG)\]' | wc -l | tr -d ' ' || true)
  [ "$cnt" = "$expected_count" ] && pass || fail "count for [$input]: expected=$expected_count got=$cnt out=[$out]"
  if [ "$expected_count" = "0" ]; then
    [ "$out" = "$input" ] && pass || fail "no-op for [$input]: out=[$out]"
  else
    printf '%s' "$out" | grep -qE "$expected_pattern" && pass || fail "pattern for [$input]: out=[$out] pat=[$expected_pattern]"
  fi
done < "$FIXTURES/redaction-cases.txt"

# === ehr_redact_meta: redaction_checked / redaction_count / redaction_failed ===
meta=$(ehr_redact_meta "20236 출산휴가 2026-04-21")
checked=$(MFP="$meta" node -e "console.log(JSON.parse(process.env.MFP).redaction_checked)")
count=$(MFP="$meta" node -e "console.log(JSON.parse(process.env.MFP).redaction_count)")
failed=$(MFP="$meta" node -e "console.log(JSON.parse(process.env.MFP).redaction_failed)")
[ "$checked" = "true" ] && pass || fail "meta.redaction_checked=$checked"
[ "$count" = "2" ] && pass || fail "meta.redaction_count=$count"
[ "$failed" = "false" ] && pass || fail "meta.redaction_failed=$failed"

# PII 없는 record 도 checked=true, count=0, failed=false (drop 되지 않아야 함)
meta2=$(ehr_redact_meta "JSP만 수정해줘")
c2=$(MFP="$meta2" node -e "console.log(JSON.parse(process.env.MFP).redaction_count)")
chk2=$(MFP="$meta2" node -e "console.log(JSON.parse(process.env.MFP).redaction_checked)")
[ "$c2" = "0" ] && pass || fail "no-PII count=0, got=$c2"
[ "$chk2" = "true" ] && pass || fail "no-PII still checked=$chk2"

# === ehr_redact_should_drop ===
drop_pii=$(ehr_redact_should_drop "$meta")
[ "$drop_pii" = "false" ] && pass || fail "should not drop normal record (got $drop_pii)"

bad_meta='{"redaction_checked":false,"redaction_count":0,"redaction_failed":true}'
drop_bad=$(ehr_redact_should_drop "$bad_meta")
[ "$drop_bad" = "true" ] && pass || fail "should drop unchecked/failed record (got $drop_bad)"

echo "ALL REDACTION TESTS PASSED  pass=$PASS fail=$FAIL_CNT"
[ "$FAIL_CNT" -eq 0 ]
