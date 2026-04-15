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

# ── JSON 유효성 검증 (full fixture 기준) ──
RESULT=$(detect_auth_model "$FX/auth_model/full" "ehr4")
echo "$RESULT" | node -e "
  let s='';process.stdin.on('data',d=>s+=d);
  process.stdin.on('end',()=>{
    try{const m=JSON.parse(s);
      if(typeof m!=='object'||m===null)throw new Error('not object');
      ['common_controllers','auth_service_class','auth_injection_methods','auth_tables','auth_functions','session_vars'].forEach(k=>{
        if(!(k in m))throw new Error('missing key: '+k);
      });
      process.exit(0);
    }catch(e){console.error(e.message);process.exit(1);}
  });
" >/dev/null 2>&1 \
  && pass "auth_model full: JSON 유효 + 필수 키 전부 존재" \
  || fail "auth_model full: JSON 파싱 실패 또는 키 누락 ($RESULT)"

# ── auth_function_call injection 검증 (full fixture) ──
RESULT=$(detect_auth_model "$FX/auth_model/full" "ehr4")
echo "$RESULT" | grep -q '"auth_function_call"' \
  && pass "auth_model full: auth_function_call injection 감지" \
  || fail "auth_model full: auth_function_call missing ($RESULT)"

# ── session_vars 배열 검증 (full fixture: ssnEnterCd/ssnSabun/ssnSearchType 3개) ──
RESULT=$(detect_auth_model "$FX/auth_model/full" "ehr4")
for sv in ssnEnterCd ssnSabun ssnSearchType; do
  echo "$RESULT" | grep -q "\"$sv\"" \
    && pass "auth_model full: session_vars에 $sv 포함" \
    || fail "auth_model full: session_vars에 $sv 없음 ($RESULT)"
done

# ── minimal: query_placeholder/auth_table_join/auth_function_call 모두 없어야 함 ──
RESULT=$(detect_auth_model "$FX/auth_model/minimal" "ehr4")
echo "$RESULT" | grep -q '"auth_injection_methods":\[\]' \
  && pass "auth_model minimal: auth_injection_methods 빈 배열" \
  || fail "auth_model minimal: auth_injection_methods should be empty ($RESULT)"

# ── table_join: query_placeholder/auth_function_call 없고 auth_table_join만 ──
RESULT=$(detect_auth_model "$FX/auth_model/table_join" "ehr4")
echo "$RESULT" | grep -q '"query_placeholder"' \
  && fail "auth_model table_join: query_placeholder should NOT be detected ($RESULT)" \
  || pass "auth_model table_join: query_placeholder 제외"
echo "$RESULT" | grep -q '"auth_function_call"' \
  && fail "auth_model table_join: auth_function_call should NOT be detected ($RESULT)" \
  || pass "auth_model table_join: auth_function_call 제외"

# ── alt_service: AuthService (대체 이름) 감지 ──
RESULT=$(detect_auth_model "$FX/auth_model/alt_service" "ehr4")
echo "$RESULT" | grep -q '"auth_service_class":"AuthService"' \
  && pass "auth_model alt_service: AuthService 감지 (대체 이름)" \
  || fail "auth_model alt_service: AuthService not detected ($RESULT)"

# ═══════════════════════════════════════════════
#   DDL 폴더 감별 테스트
# ═══════════════════════════════════════════════

# ── ddl_folder/present: 기본 경로 감지 ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/present")
echo "$RESULT" | grep -q '"enabled":true' \
  && pass "ddl_folder present: enabled=true" \
  || fail "ddl_folder present: not enabled ($RESULT)"
echo "$RESULT" | grep -q '"table_path":".*db/tables"' \
  && pass "ddl_folder present: table_path 감지" \
  || fail "ddl_folder present: table_path missing ($RESULT)"
echo "$RESULT" | grep -q '"THRM101"' \
  && pass "ddl_folder present: existing_tables에 THRM101" \
  || fail "ddl_folder present: existing_tables ($RESULT)"
echo "$RESULT" | grep -q '"THRM102"' \
  && pass "ddl_folder present: existing_tables에 THRM102" \
  || fail "ddl_folder present: existing_tables missing THRM102 ($RESULT)"

# ── ddl_folder/absent: 폴더 없음 ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/absent")
echo "$RESULT" | grep -q '"enabled":false' \
  && pass "ddl_folder absent: enabled=false" \
  || fail "ddl_folder absent: should be disabled ($RESULT)"
echo "$RESULT" | grep -q '"existing_tables":\[\]' \
  && pass "ddl_folder absent: existing_tables 빈 배열" \
  || fail "ddl_folder absent: existing_tables should be empty ($RESULT)"

# ── ddl_folder/tbl_prefix: TBL_ prefix 명명 규칙 ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/tbl_prefix")
echo "$RESULT" | grep -q '"naming_pattern":"TBL_{OBJECT_NAME}.sql"' \
  && pass "ddl_folder tbl_prefix: naming_pattern 추출" \
  || fail "ddl_folder tbl_prefix: naming_pattern missing ($RESULT)"
echo "$RESULT" | grep -q '"TCODE"' \
  && pass "ddl_folder tbl_prefix: existing_tables에 TCODE" \
  || fail "ddl_folder tbl_prefix: TCODE missing ($RESULT)"

# ── JSON 유효성 (present fixture) ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/present")
echo "$RESULT" | node -e "
  let s='';process.stdin.on('data',d=>s+=d);
  process.stdin.on('end',()=>{
    try{const m=JSON.parse(s);
      if(typeof m!=='object'||m===null)throw new Error('not object');
      ['enabled','table_path','procedure_path','function_path','naming_pattern','header_template_path','existing_tables'].forEach(k=>{
        if(!(k in m))throw new Error('missing key: '+k);
      });
      if(!Array.isArray(m.existing_tables))throw new Error('existing_tables not array');
      process.exit(0);
    }catch(e){console.error(e.message);process.exit(1);}
  });
" >/dev/null 2>&1 \
  && pass "ddl_folder present: JSON 유효 + 필수 키 전부 존재" \
  || fail "ddl_folder present: JSON 파싱 실패 또는 키 누락 ($RESULT)"

# ── ddl_folder/or_replace: CREATE OR REPLACE 지원 ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/or_replace")
echo "$RESULT" | grep -q '"enabled":true' \
  && pass "ddl_folder or_replace: enabled=true" \
  || fail "ddl_folder or_replace: not enabled ($RESULT)"
echo "$RESULT" | grep -q '"TREPLACE"' \
  && pass "ddl_folder or_replace: TREPLACE 추출" \
  || fail "ddl_folder or_replace: TREPLACE missing ($RESULT)"

# ── ddl_folder/tricky_names: 주석/스키마/IF NOT EXISTS/따옴표 처리 ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/tricky_names")
echo "$RESULT" | grep -q '"TFAKE"' \
  && fail "ddl_folder tricky_names: TFAKE (주석) 잘못 추출됨 ($RESULT)" \
  || pass "ddl_folder tricky_names: 주석 라인 제외"
echo "$RESULT" | grep -q '"TQUALIFIED"' \
  && pass "ddl_folder tricky_names: HR.TQUALIFIED → TQUALIFIED" \
  || fail "ddl_folder tricky_names: schema prefix 제거 실패 ($RESULT)"
echo "$RESULT" | grep -q '"TNOTEXIST"' \
  && pass "ddl_folder tricky_names: IF NOT EXISTS 건너뛰기" \
  || fail "ddl_folder tricky_names: IF NOT EXISTS 처리 실패 ($RESULT)"
echo "$RESULT" | grep -q '"TQUOTED"' \
  && pass "ddl_folder tricky_names: 따옴표 이름 처리" \
  || fail "ddl_folder tricky_names: quoted name 처리 실패 ($RESULT)"
echo "$RESULT" | grep -q '"IF"' \
  && fail "ddl_folder tricky_names: IF 키워드가 테이블명으로 추출됨 ($RESULT)" \
  || pass "ddl_folder tricky_names: IF 키워드 제외"

# ── Windows 경로 JSON escape 검증 (Linux/git-bash에서도 항상 테스트) ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/present")
echo "$RESULT" | node -e "
  let s='';process.stdin.on('data',d=>s+=d);
  process.stdin.on('end',()=>{
    try{JSON.parse(s);process.exit(0);}catch(e){console.error(e.message);process.exit(1);}
  });
" >/dev/null 2>&1 \
  && pass "ddl_folder present: JSON.parse 성공 (경로 escape 무결성)" \
  || fail "ddl_folder present: JSON.parse 실패 ($RESULT)"

echo "ALL AUTH_MODEL DETECTION TESTS PASSED"
echo "ALL DDL_FOLDER DETECTION TESTS PASSED"
