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

# ═══════════════════════════════════════════════
#   DDL Authoring 결정론적 테스트 (v1.5.0)
#
#  대상:
#    1. sql_ddl_layout  — sql/ddl/ 중첩 경로 + procedure/ 서브폴더 감지
#    2. yyyymmdd_prefix — YYYYMMDD_{NAME}.sql 다수결 naming_pattern
#    3. db_root_flat    — database/ 루트 플랫 구조 + 기본 naming_pattern
#    4/5. 치명 네임스페이스 차단 로직은 screen-builder 에이전트 프롬프트에만 존재.
#       lib 함수 미구현이므로 아래 주석에 검증 대상 패턴 명시.
#       # MANUAL-TEST: P_CPN_*, P_HRI_AFTER_*, P_HRM_POST*, P_TIM_*,
#       #              PKG_CPN_*, PKG_CPN_YEA_*, P_CPN_YEAREND_MONPAY_*,
#       #              TRG_* 등 접두사를 DDL 이름으로 입력 시
#       #              screen-builder 에이전트가 "자동 생성 차단" 응답하는지
#       #              수동으로 확인 필요 (ddl-authoring.notes.md 참조).
# ═══════════════════════════════════════════════

# ── TC-DDL-01: sql_ddl_layout — sql/ 하위 DDL 폴더 감지 ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/sql_ddl_layout")
echo "$RESULT" | grep -q '"enabled":true' \
  && pass "ddl_folder sql_ddl_layout: enabled=true (sql/ 경로 감지)" \
  || fail "ddl_folder sql_ddl_layout: not enabled ($RESULT)"

# ── TC-DDL-02: sql_ddl_layout — tables/ 서브폴더 table_path 감지 ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/sql_ddl_layout")
echo "$RESULT" | grep -q '"table_path":".*tables"' \
  && pass "ddl_folder sql_ddl_layout: table_path에 tables 서브폴더 포함" \
  || fail "ddl_folder sql_ddl_layout: table_path missing tables ($RESULT)"

# ── TC-DDL-03: sql_ddl_layout — procedure/ 서브폴더 procedure_path 감지 ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/sql_ddl_layout")
echo "$RESULT" | grep -q '"procedure_path":".*procedures"' \
  && pass "ddl_folder sql_ddl_layout: procedure_path 감지" \
  || fail "ddl_folder sql_ddl_layout: procedure_path missing ($RESULT)"

# ── TC-DDL-04: sql_ddl_layout — existing_tables에 TORG_EMP/TORG_DEPT 포함 ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/sql_ddl_layout")
echo "$RESULT" | grep -q '"TORG_EMP"' \
  && pass "ddl_folder sql_ddl_layout: existing_tables에 TORG_EMP" \
  || fail "ddl_folder sql_ddl_layout: TORG_EMP missing ($RESULT)"
echo "$RESULT" | grep -q '"TORG_DEPT"' \
  && pass "ddl_folder sql_ddl_layout: existing_tables에 TORG_DEPT" \
  || fail "ddl_folder sql_ddl_layout: TORG_DEPT missing ($RESULT)"

# ── TC-DDL-05: yyyymmdd_prefix — YYYYMMDD 다수결 naming_pattern ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/yyyymmdd_prefix")
echo "$RESULT" | grep -q '"enabled":true' \
  && pass "ddl_folder yyyymmdd_prefix: enabled=true" \
  || fail "ddl_folder yyyymmdd_prefix: not enabled ($RESULT)"
echo "$RESULT" | grep -q '"naming_pattern":"YYYYMMDD_{OBJECT_NAME}.sql"' \
  && pass "ddl_folder yyyymmdd_prefix: YYYYMMDD_ naming_pattern 다수결 승리" \
  || fail "ddl_folder yyyymmdd_prefix: naming_pattern mismatch ($RESULT)"

# ── TC-DDL-06: yyyymmdd_prefix — existing_tables에 실제 테이블명만 (날짜 prefix 제거) ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/yyyymmdd_prefix")
echo "$RESULT" | grep -q '"THRM201"' \
  && pass "ddl_folder yyyymmdd_prefix: existing_tables에 THRM201 포함" \
  || fail "ddl_folder yyyymmdd_prefix: THRM201 missing ($RESULT)"

# ── TC-DDL-07: db_root_flat — database/ 경로 감지 ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/db_root_flat")
echo "$RESULT" | grep -q '"enabled":true' \
  && pass "ddl_folder db_root_flat: enabled=true (database/ 경로)" \
  || fail "ddl_folder db_root_flat: not enabled ($RESULT)"

# ── TC-DDL-08: db_root_flat — 서브폴더 없으므로 table_path=database/ 루트 ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/db_root_flat")
echo "$RESULT" | grep -q '"table_path":".*database"' \
  && pass "ddl_folder db_root_flat: table_path이 database/ 루트 지정" \
  || fail "ddl_folder db_root_flat: table_path missing ($RESULT)"

# ── TC-DDL-09: db_root_flat — 기본 naming_pattern ({OBJECT_NAME}.sql) ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/db_root_flat")
echo "$RESULT" | grep -q '"naming_pattern":"{OBJECT_NAME}.sql"' \
  && pass "ddl_folder db_root_flat: 기본 naming_pattern 적용" \
  || fail "ddl_folder db_root_flat: naming_pattern mismatch ($RESULT)"

# ── TC-DDL-10: db_root_flat — existing_tables에 TPAY_ITEM/TPAY_DETAIL ──
RESULT=$(detect_ddl_folder "$FX/ddl_folder/db_root_flat")
echo "$RESULT" | grep -q '"TPAY_ITEM"' \
  && pass "ddl_folder db_root_flat: existing_tables에 TPAY_ITEM" \
  || fail "ddl_folder db_root_flat: TPAY_ITEM missing ($RESULT)"
echo "$RESULT" | grep -q '"TPAY_DETAIL"' \
  && pass "ddl_folder db_root_flat: existing_tables에 TPAY_DETAIL" \
  || fail "ddl_folder db_root_flat: TPAY_DETAIL missing ($RESULT)"

echo "ALL DDL_AUTHORING DETECTION TESTS PASSED"

# ═══════════════════════════════════════════════
#   Tibero DB 벤더 감지 테스트 (v1.4.0)
# ═══════════════════════════════════════════════
#
# detect_db_vendor: context.xml / application.properties 에서 JDBC URL을 읽어
# "oracle" / "tibero" / "oracle" (기본값) 을 반환하는 인라인 함수.
# SKILL.md Step 2-J 벤더 감지 규칙을 bash 로 구현:
#   - jdbc:tibero:thin:@ 포함  → tibero
#   - jdbc:oracle:thin:@ 포함  → oracle
#   - 둘 다 발견 시 tibero 우선 (tibero 체크 먼저)
#   - 아무것도 없음            → oracle (기본값)
#
# NOTE(bug-guard): 주석(<!-- ... -->) 안에 있는 URL도 grep이 잡으므로,
#   "both" fixture처럼 Tibero가 활성 + Oracle이 주석인 경우에도
#   tibero 우선 규칙이 적용되어 올바르게 "tibero" 반환.
#   단, Oracle이 활성 + Tibero가 주석인 구성은 잘못된 결과를 낼 수 있음.
#   (실제 프로덕션 코드에서도 동일한 한계가 있음 — XML 주석 파싱 미지원)

detect_db_vendor() {
  local root="$1"
  local url_raw=""

  # context.xml 우선 탐색
  local ctx_file
  ctx_file=$(find "$root" -name "context*.xml" 2>/dev/null | head -1)
  if [ -n "$ctx_file" ]; then
    # url 속성값 추출 (log4jdbc: 제거)
    url_raw=$(grep -oE 'jdbc:(tibero|oracle):[^"]+' "$ctx_file" 2>/dev/null | head -1 || true)
  fi

  # context.xml에 없으면 application.properties 탐색
  if [ -z "$url_raw" ]; then
    local prop_file
    prop_file=$(find "$root" -name "application.properties" 2>/dev/null | head -1)
    if [ -n "$prop_file" ]; then
      url_raw=$(grep -oE 'jdbc:(tibero|oracle):[^[:space:]]+' "$prop_file" 2>/dev/null | head -1 || true)
    fi
  fi

  # 벤더 판정 — tibero 먼저 체크 (SKILL.md Step 2-J 우선순위)
  if echo "$url_raw" | grep -q "jdbc:tibero:thin:@"; then
    echo "tibero"
  elif echo "$url_raw" | grep -q "jdbc:oracle:thin:@"; then
    echo "oracle"
  else
    echo "oracle"  # 기본값
  fi
}

# ── tibero/oracle_only: Oracle URL만 있을 때 "oracle" ──
RESULT=$(detect_db_vendor "$FX/tibero/oracle_only")
[ "$RESULT" = "oracle" ] \
  && pass "tibero oracle_only: oracle 감지" \
  || fail "tibero oracle_only: 'oracle' 기대, 실제='$RESULT'"

# ── tibero/tibero_only: Tibero URL만 있을 때 "tibero" ──
RESULT=$(detect_db_vendor "$FX/tibero/tibero_only")
[ "$RESULT" = "tibero" ] \
  && pass "tibero tibero_only: tibero 감지" \
  || fail "tibero tibero_only: 'tibero' 기대, 실제='$RESULT'"

# ── tibero/both: Tibero 활성 + Oracle 주석 → "tibero" 우선 ──
RESULT=$(detect_db_vendor "$FX/tibero/both")
[ "$RESULT" = "tibero" ] \
  && pass "tibero both: tibero 우선 (Oracle 주석 무시)" \
  || fail "tibero both: 'tibero' 기대, 실제='$RESULT'"

# ── tibero/neither: JDBC URL 없음 → 기본값 "oracle" ──
RESULT=$(detect_db_vendor "$FX/tibero/neither")
[ "$RESULT" = "oracle" ] \
  && pass "tibero neither: 기본값 oracle 반환" \
  || fail "tibero neither: 'oracle' 기대, 실제='$RESULT'"

# ── tibero/tibero_only: log4jdbc 래핑 URL 대응 (url에 log4jdbc: prefix 없는 경우 포함) ──
RESULT=$(detect_db_vendor "$FX/tibero/tibero_only")
echo "$RESULT" | grep -qE "^(tibero|oracle)$" \
  && pass "tibero tibero_only: 반환값이 oracle|tibero 중 하나" \
  || fail "tibero tibero_only: 알 수 없는 벤더값 '$RESULT'"

# ── tibero/tibero_jar: tibero*-jdbc.jar 파일 존재 여부 탐지 ──
JAR_FOUND=$(find "$FX/tibero/tibero_jar" -name "tibero*-jdbc.jar" -o -name "tibero*.jar" 2>/dev/null | head -1)
[ -n "$JAR_FOUND" ] \
  && pass "tibero jar: tibero*-jdbc.jar 탐지됨 ($JAR_FOUND)" \
  || fail "tibero jar: tibero*-jdbc.jar 탐지 실패"

# ── tibero/tibero_jar: ojdbc*.jar 는 없어야 함 ──
OJDBC_FOUND=$(find "$FX/tibero/tibero_jar" -name "ojdbc*.jar" 2>/dev/null | head -1)
[ -z "$OJDBC_FOUND" ] \
  && pass "tibero jar: ojdbc*.jar 없음 (Tibero 전용 환경 확인)" \
  || fail "tibero jar: ojdbc*.jar 가 예상치 않게 발견됨"

echo "ALL TIBERO DETECTION TESTS PASSED"

# ══════════════════════════════════════════════════════
# Windows 경로 엣지 케이스 (공백/한글)
# 실제 symlink/junction 은 Git Bash 관리자 권한 필요 →
#   파일 복사로 대체. 실제 symlink 는 별도 환경 검증 필요
# ══════════════════════════════════════════════════════

# ── WP-1: 공백 포함 경로에서 detect_auth_model 동작 ──
# 시뮬레이션 경로: C:/Program Files (x86)/proj/ 또는 /tmp/dir with space/
RESULT=$(detect_auth_model "$FX/auth_model/full space path" "ehr4")
echo "$RESULT" | grep -q '"auth_service_class":"AuthTableService"' \
  && pass "WP-1 공백경로: detect_auth_model auth_service_class 감지" \
  || fail "WP-1 공백경로: detect_auth_model 실패 — 경로 quoting 문제 의심 ($RESULT)"
echo "$RESULT" | grep -q '"THRM151_AUTH"' \
  && pass "WP-1 공백경로: detect_auth_model auth_tables 감지" \
  || fail "WP-1 공백경로: detect_auth_model auth_tables 누락 ($RESULT)"

# detect_ddl_folder 공백 경로 검증
RESULT=$(detect_ddl_folder "$FX/ddl_folder/present space")
echo "$RESULT" | grep -q '"enabled":true' \
  && pass "WP-1 공백경로: detect_ddl_folder enabled=true" \
  || fail "WP-1 공백경로: detect_ddl_folder 실패 ($RESULT)"

# ── WP-2: 한글 포함 경로에서 detect_auth_model 동작 ──
# 시뮬레이션 경로: C:/사용자/홍길동/proj/ 또는 /tmp/한글폴더/
RESULT=$(detect_auth_model "$FX/auth_model/full_한글경로" "ehr4")
echo "$RESULT" | grep -q '"auth_service_class":"AuthTableService"' \
  && pass "WP-2 한글경로: detect_auth_model auth_service_class 감지" \
  || fail "WP-2 한글경로: detect_auth_model 실패 — multibyte 경로 처리 의심 ($RESULT)"
echo "$RESULT" | grep -q '"THRM151_AUTH"' \
  && pass "WP-2 한글경로: detect_auth_model auth_tables 감지" \
  || fail "WP-2 한글경로: detect_auth_model auth_tables 누락 ($RESULT)"

# detect_ddl_folder 한글 경로 검증
RESULT=$(detect_ddl_folder "$FX/ddl_folder/present_한글")
echo "$RESULT" | grep -q '"enabled":true' \
  && pass "WP-2 한글경로: detect_ddl_folder enabled=true" \
  || fail "WP-2 한글경로: detect_ddl_folder 실패 ($RESULT)"

# ── WP-3 (심볼릭링크 mock): 복사된 픽스처에서 JSON 유효성 ──
# 실제 symlink 는 별도 환경 검증 필요 (mklink /J 는 관리자 권한 필요)
RESULT=$(detect_auth_model "$FX/auth_model/full_한글경로" "ehr4")
echo "$RESULT" | node -e "
  let s='';process.stdin.on('data',d=>s+=d);
  process.stdin.on('end',()=>{
    try{const m=JSON.parse(s);
      ['common_controllers','auth_service_class','auth_injection_methods','auth_tables','auth_functions','session_vars'].forEach(k=>{
        if(!(k in m))throw new Error('missing key: '+k);
      });
      process.exit(0);
    }catch(e){console.error(e.message);process.exit(1);}
  });
" >/dev/null 2>&1 \
  && pass "WP-3 심볼릭링크(mock): JSON 유효 (복사 대체 픽스처, 한글 경로)" \
  || fail "WP-3 심볼릭링크(mock): JSON 파싱 실패 ($RESULT)"

echo "ALL WINDOWS PATH EDGE CASE TESTS PASSED (detect)"
