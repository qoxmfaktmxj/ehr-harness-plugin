#!/usr/bin/env bash
# detect.test.sh — 권한 모델 / DDL 폴더 감별 함수 테스트
#
# 실행: bash detect.test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/detect.sh"

FX="$SCRIPT_DIR/fixtures"

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; }

# ── auth_model/full: 모든 요소 감지 ──
RESULT=$(detect_auth_model "$FX/auth_model/full" "ehr4")
echo "$RESULT" | grep -q '"common_controllers":\[.*"GetDataList".*"SaveData".*\]' \
  && pass "auth_model full: common_controllers" \
  || fail "auth_model full: common_controllers missing ($RESULT)"
echo "$RESULT" | grep -q '"auth_service_class":"AuthTableService"' \
  && pass "auth_model full: auth_service_class" \
  || fail "auth_model full: auth_service_class ($RESULT)"
echo "$RESULT" | grep -q '"query_placeholder"' \
  && pass "auth_model full: query_placeholder injection" \
  || fail "auth_model full: query_placeholder missing ($RESULT)"
echo "$RESULT" | grep -q '"auth_table_join"' \
  && pass "auth_model full: auth_table_join injection" \
  || fail "auth_model full: auth_table_join missing ($RESULT)"
echo "$RESULT" | grep -q '"THRM151_AUTH"' \
  && pass "auth_model full: auth_tables" \
  || fail "auth_model full: THRM151_AUTH missing ($RESULT)"
echo "$RESULT" | grep -q '"F_COM_GET_SQL_AUTH"' \
  && pass "auth_model full: auth_functions" \
  || fail "auth_model full: F_COM_GET_SQL_AUTH missing ($RESULT)"

# ── auth_model/minimal: 법칙 A만 ──
RESULT=$(detect_auth_model "$FX/auth_model/minimal" "ehr4")
echo "$RESULT" | grep -q '"common_controllers":\[\]' \
  && pass "auth_model minimal: common_controllers 빈 배열" \
  || fail "auth_model minimal: common_controllers not empty ($RESULT)"
echo "$RESULT" | grep -q '"auth_service_class":null' \
  && pass "auth_model minimal: auth_service_class null" \
  || fail "auth_model minimal: auth_service_class not null ($RESULT)"

# ── auth_model/table_join: AuthTableService 없이 JOIN만 ──
RESULT=$(detect_auth_model "$FX/auth_model/table_join" "ehr4")
echo "$RESULT" | grep -q '"auth_service_class":null' \
  && pass "auth_model table_join: auth_service_class null" \
  || fail "auth_model table_join: auth_service_class not null ($RESULT)"
echo "$RESULT" | grep -q '"auth_table_join"' \
  && pass "auth_model table_join: auth_table_join detected" \
  || fail "auth_model table_join: detection failed ($RESULT)"

echo "ALL AUTH_MODEL DETECTION TESTS PASSED"
