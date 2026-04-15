#!/usr/bin/env bash
# detect.sh — 권한 모델 / DDL 폴더 감별 함수
#
# 사용 예:
#   source detect.sh
#   detect_auth_model "./project_root" "ehr4"
#   detect_ddl_folder "./project_root"

set -u

# TODO(portability): \s+ 는 GNU grep 확장. macOS BSD grep 지원 시 [[:space:]]+ 로 통일 필요.
#                    (이미 I5 fix로 대부분 치환 완료; 혹시 남은 곳 발견 시 수정)
# TODO(session_vars): session.getAttribute("...") 리터럴만 감지. `req.getSession().getAttribute(...)`
#                    또는 상수 키 (`session.getAttribute(KEY)`) 패턴은 누락됨. EHR 관행상 세션 변수명은
#                    거의 항상 리터럴이므로 실용상 문제 없음.

# ── 권한 모델 감별 ──
# args: project_root profile(ehr4|ehr5)
# stdout: JSON {common_controllers, auth_service_class, auth_injection_methods, auth_tables, auth_functions, session_vars}
detect_auth_model() {
  local root="$1"
  local profile="${2:-ehr4}"

  # Java 경로 & 매퍼 확장자 결정
  local java_root mapper_ext
  if [ "$profile" = "ehr5" ]; then
    java_root="$root/src/main/java"
    mapper_ext="*-sql-query.xml"
  else
    java_root="$root/src"
    mapper_ext="*-mapping-query.xml"
  fi
  # java_root 없으면 root 전체 스캔 fallback
  if [ ! -d "$java_root" ]; then
    java_root="$root"
  fi

  # 1) 공통 컨트롤러 존재 여부
  local common=()
  for ctrl in GetDataList SaveData ExecPrc; do
    if grep -rlE "class[[:space:]]+${ctrl}Controller([[:space:]{<]|$)" --include="*.java" "$java_root" >/dev/null 2>&1; then
      common+=("\"$ctrl\"")
    fi
  done
  local common_json
  common_json=$(IFS=,; echo "[${common[*]:-}]")

  # 2) AuthTableService 존재 여부 — 우선순위 순서로 스캔 (가장 구체적인 이름 우선)
  local auth_service="null"
  for svc_name in AuthTableService SqlAuthService AuthService; do
    if grep -rqE "class[[:space:]]+${svc_name}([[:space:]{<]|$)" --include="*.java" "$java_root" 2>/dev/null; then
      auth_service="\"$svc_name\""
      break
    fi
  done

  # 3) 권한 주입 방식
  local methods=()
  # query_placeholder — ${query} 또는 $query (식별자 경계 엄격)
  if grep -rqE '\$\{query\}|\$query([^A-Za-z0-9_]|$)' --include="$mapper_ext" --include="*.xml" "$root" 2>/dev/null; then
    methods+=("\"query_placeholder\"")
  fi
  # auth_table_join — THRM151_AUTH 또는 THRM152_AUTH_MENU 직접 JOIN
  if grep -rqE 'JOIN\s+THRM[0-9]+_AUTH' --include="$mapper_ext" --include="*.xml" "$root" 2>/dev/null; then
    methods+=("\"auth_table_join\"")
  fi
  # auth_function_call — F_COM_GET_SQL_AUTH 같은 함수
  if grep -rqE 'F_COM_GET_[A-Z_]+AUTH' --include="$mapper_ext" --include="*.xml" "$root" 2>/dev/null; then
    methods+=("\"auth_function_call\"")
  fi
  local methods_json
  methods_json=$(IFS=,; echo "[${methods[*]:-}]")

  # 4) 권한 테이블 목록 (THRM1xx_AUTH 패턴)
  local auth_tables=()
  while IFS= read -r tbl; do
    [ -n "$tbl" ] && auth_tables+=("\"$tbl\"")
  done < <(grep -rhoE 'THRM[0-9]+_AUTH[A-Z_]*' --include="$mapper_ext" --include="*.xml" "$root" 2>/dev/null | sort -u)
  local auth_tables_json
  auth_tables_json=$(IFS=,; echo "[${auth_tables[*]:-}]")

  # 5) 권한 함수 목록
  local auth_functions=()
  while IFS= read -r fn; do
    [ -n "$fn" ] && auth_functions+=("\"$fn\"")
  done < <(grep -rhoE 'F_COM_GET_[A-Z_]+AUTH' --include="$mapper_ext" --include="*.xml" "$root" 2>/dev/null | sort -u)
  local auth_functions_json
  auth_functions_json=$(IFS=,; echo "[${auth_functions[*]:-}]")

  # 6) 세션 변수 목록
  local session_vars=()
  while IFS= read -r sv; do
    [ -n "$sv" ] && session_vars+=("\"$sv\"")
  done < <(grep -rhoE 'session\.getAttribute\("[a-zA-Z0-9_]+"\)' --include="*.java" "$java_root" 2>/dev/null \
             | grep -oE '"[a-zA-Z0-9_]+"' | sort -u | sed 's/^"//;s/"$//')
  local session_vars_json
  session_vars_json=$(IFS=,; echo "[${session_vars[*]:-}]")

  # JSON 조립
  cat <<EOF
{"common_controllers":$common_json,"auth_service_class":$auth_service,"auth_injection_methods":$methods_json,"auth_tables":$auth_tables_json,"auth_functions":$auth_functions_json,"session_vars":$session_vars_json}
EOF
}

# ── DDL 폴더 감별 ──
# args: project_root
# stdout: JSON {enabled, table_path, procedure_path, function_path, naming_pattern, header_template_path, existing_tables}
detect_ddl_folder() {
  local root="$1"
  local candidates=(
    "src/main/resources/db"
    "src/main/resources/ddl"
    "src/main/resources/sql"
    "db"
    "ddl"
    "sql"
    "database"
    "schema"
  )

  local found_root=""
  for c in "${candidates[@]}"; do
    if [ -d "$root/$c" ]; then
      # CREATE TABLE 하나라도 있으면 진짜 DDL 폴더로 인정
      if grep -rqlE "CREATE[[:space:]]+(OR[[:space:]]+REPLACE[[:space:]]+)?TABLE" "$root/$c" 2>/dev/null; then
        found_root="$root/$c"
        break
      fi
    fi
  done

  if [ -z "$found_root" ]; then
    echo '{"enabled":false,"table_path":null,"procedure_path":null,"function_path":null,"naming_pattern":null,"header_template_path":null,"existing_tables":[]}'
    return 0
  fi

  # 서브구조 감별
  local table_path="null" proc_path="null" func_path="null"
  for tbl_sub in tables table tbl; do
    if [ -d "$found_root/$tbl_sub" ]; then
      table_path="\"$found_root/$tbl_sub\""
      break
    fi
  done
  if [ "$table_path" = "null" ]; then
    table_path="\"$found_root\""
  fi
  for proc_sub in procedures procedure proc; do
    if [ -d "$found_root/$proc_sub" ]; then
      proc_path="\"$found_root/$proc_sub\""
      break
    fi
  done
  for fn_sub in functions function func; do
    if [ -d "$found_root/$fn_sub" ]; then
      func_path="\"$found_root/$fn_sub\""
      break
    fi
  done

  # 명명 규칙 샘플링 (테이블 파일 2~3개 이름 분석)
  local sample_file
  sample_file=$(find "${table_path//\"/}" -maxdepth 2 -name "*.sql" 2>/dev/null | head -1)
  local naming_pattern="\"{OBJECT_NAME}.sql\""
  if [ -n "$sample_file" ]; then
    local fname
    fname=$(basename "$sample_file")
    # TBL_xxx.sql 패턴인가?
    if echo "$fname" | grep -qE '^TBL_'; then
      naming_pattern="\"TBL_{OBJECT_NAME}.sql\""
    # YYYYMMDD_xxx.sql 패턴인가?
    elif echo "$fname" | grep -qE '^[0-9]{8}_'; then
      naming_pattern="\"YYYYMMDD_{OBJECT_NAME}.sql\""
    fi
  fi

  # 기존 테이블 이름 세트
  local existing=()
  while IFS= read -r tbl; do
    [ -n "$tbl" ] && existing+=("\"$tbl\"")
  done < <(grep -rhoE "CREATE[[:space:]]+(OR[[:space:]]+REPLACE[[:space:]]+)?TABLE[[:space:]]+[A-Z][A-Z0-9_]+" "${table_path//\"/}" 2>/dev/null \
             | sed -E 's/CREATE[[:space:]]+(OR[[:space:]]+REPLACE[[:space:]]+)?TABLE[[:space:]]+//' | sort -u)
  local existing_json
  existing_json=$(IFS=,; echo "[${existing[*]:-}]")

  cat <<EOF
{"enabled":true,"table_path":$table_path,"procedure_path":$proc_path,"function_path":$func_path,"naming_pattern":$naming_pattern,"header_template_path":null,"existing_tables":$existing_json}
EOF
}
