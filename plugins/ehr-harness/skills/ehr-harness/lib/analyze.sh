#!/usr/bin/env bash
# analyze.sh — 프로젝트 분석 결과를 JSON으로 집계
#
# 사용 예:
#   source analyze.sh
#   collect_module_map "./project" "ehr5"
#   collect_session_vars "./project" "ehr5"
#   build_analysis_json "./project" "ehr5"

set -u

# ── 경로 결정 헬퍼 ──
_java_root() {
  local root="$1"
  local profile="${2:-ehr4}"
  if [ "$profile" = "ehr5" ]; then
    echo "$root/src/main/java"
  else
    echo "$root/src"
  fi
}

_mapper_ext() {
  local profile="${1:-ehr4}"
  if [ "$profile" = "ehr5" ]; then
    echo "*-sql-query.xml"
  else
    echo "*-mapping-query.xml"
  fi
}

# ── 모듈 맵 수집 ──
# args: project_root profile
# stdout: JSON 배열 [{name, file_count}, ...]
collect_module_map() {
  local root="$1"
  local profile="${2:-ehr4}"
  local java_root
  java_root=$(_java_root "$root" "$profile")

  if [ ! -d "$java_root" ]; then
    java_root="$root"
  fi

  # com/hr 하위 모듈 이름 수집 (표준 EHR 레이아웃)
  local hr_root
  if [ -d "$java_root/com/hr" ]; then
    hr_root="$java_root/com/hr"
  else
    hr_root="$java_root"
  fi

  local entries=()
  if [ -d "$hr_root" ]; then
    while IFS= read -r mod; do
      [ -z "$mod" ] && continue
      local name
      name=$(basename "$mod")
      local count
      count=$(find "$mod" -name "*.java" 2>/dev/null | wc -l | tr -d ' ')
      entries+=("{\"name\":\"$name\",\"file_count\":$count}")
    done < <(find "$hr_root" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
  fi

  local joined
  joined=$(IFS=,; echo "${entries[*]:-}")
  echo "[$joined]"
}

# ── 세션 변수 수집 ──
# args: project_root profile
# stdout: JSON 배열 ["ssnEnterCd", "ssnSabun", ...]
collect_session_vars() {
  local root="$1"
  local profile="${2:-ehr4}"
  local java_root
  java_root=$(_java_root "$root" "$profile")
  if [ ! -d "$java_root" ]; then
    java_root="$root"
  fi

  local vars=()
  while IFS= read -r sv; do
    [ -n "$sv" ] && vars+=("\"$sv\"")
  done < <(grep -rhoE 'session\.getAttribute\("[a-zA-Z0-9_]+"\)' --include="*.java" "$java_root" 2>/dev/null \
             | grep -oE '"[a-zA-Z0-9_]+"' | sort -u | sed 's/^"//;s/"$//')

  local joined
  joined=$(IFS=,; echo "${vars[*]:-}")
  echo "[$joined]"
}

# ── authSqlID 값 수집 ──
# args: project_root profile
# stdout: JSON 배열 ["THRM151", ...]
collect_authSqlID() {
  local root="$1"
  local ids=()
  while IFS= read -r id; do
    [ -n "$id" ] && ids+=("\"$id\"")
  done < <(grep -rhoE 'authSqlID["'\''[:space:]=]*"[A-Z]{4}[0-9]{3}"' --include="*.java" --include="*.jsp" "$root" 2>/dev/null \
             | grep -oE '"[A-Z]{4}[0-9]{3}"' | sed 's/^"//;s/"$//' | sort -u)

  local joined
  joined=$(IFS=,; echo "${ids[*]:-}")
  echo "[$joined]"
}

# ── 법칙 카운트 수집 ──
# args: project_root profile
# stdout: JSON 객체 {A_direct_controller, B_getData, B_saveData, C_hybrid, D_execPrc}
collect_law_counts() {
  local root="$1"
  local profile="${2:-ehr4}"
  local java_root
  java_root=$(_java_root "$root" "$profile")
  if [ ! -d "$java_root" ]; then
    java_root="$root"
  fi

  local jsp_root
  if [ "$profile" = "ehr5" ]; then
    jsp_root="$root/src/main/webapp/WEB-INF/jsp"
  else
    jsp_root="$root/WebContent/WEB-INF/jsp"
  fi
  if [ ! -d "$jsp_root" ]; then
    jsp_root="$root"
  fi

  # B_getData: GetDataList.do 호출 JSP 수
  local b_get
  b_get=$(grep -rlE "GetDataList\\.do" --include="*.jsp" "$jsp_root" 2>/dev/null | wc -l | tr -d ' ')

  # B_saveData: SaveData.do 호출 JSP 수
  local b_save
  b_save=$(grep -rlE "SaveData\\.do" --include="*.jsp" "$jsp_root" 2>/dev/null | wc -l | tr -d ' ')

  # D_execPrc: ExecPrc.do 호출 JSP 수
  local d_exec
  d_exec=$(grep -rlE "ExecPrc\\.do" --include="*.jsp" "$jsp_root" 2>/dev/null | wc -l | tr -d ' ')

  # C_hybrid: AuthTableService 참조 파일 수
  local c_hyb
  c_hyb=$(grep -rlE "AuthTableService" --include="*.java" "$java_root" 2>/dev/null | wc -l | tr -d ' ')

  # A_direct_controller: 전용 Controller 수 - 공통/AuthTableService 제외
  local total_ctrl
  total_ctrl=$(grep -rlE "class[[:space:]]+[A-Z][A-Za-z0-9_]*Controller" --include="*.java" "$java_root" 2>/dev/null | wc -l | tr -d ' ')
  local common_ctrl
  common_ctrl=$(grep -rlE "class[[:space:]]+(GetDataList|SaveData|ExecPrc)Controller" --include="*.java" "$java_root" 2>/dev/null | wc -l | tr -d ' ')
  local a_direct=$(( total_ctrl - common_ctrl - c_hyb ))
  [ $a_direct -lt 0 ] && a_direct=0

  cat <<EOF
{"A_direct_controller":$a_direct,"B_getData":$b_get,"B_saveData":$b_save,"C_hybrid":$c_hyb,"D_execPrc":$d_exec}
EOF
}

# ── 치명 프로시저 존재 확인 ──
# args: project_root profile
# stdout: JSON 객체 {found: [...], missing: [...]}
collect_critical_proc() {
  local root="$1"
  local profile="${2:-ehr4}"
  local mapper_ext
  mapper_ext=$(_mapper_ext "$profile")

  # 치명 프로시저 고정 목록
  local critical_list=(
    P_CPN_CAL_PAY_MAIN
    P_CPN_SMPPYM_EMP
    P_CPN_ORIGIN_TAX_INS
    P_HRM_POST
    P_HRM_POST_DETAIL
    P_TIM_WORK_HOUR_CHG
    P_HRI_AFTER_PROC_EXEC
    P_HRI_APP_PATH_INS_AUTO_ALL
    P_TIM_VACATION_CLEAN
    P_TIM_ANNUAL_CREATE
  )

  local found=()
  local missing=()
  for proc in "${critical_list[@]}"; do
    if grep -rqlE "\b${proc}\b" --include="$mapper_ext" --include="*.xml" "$root" 2>/dev/null; then
      found+=("\"$proc\"")
    else
      missing+=("\"$proc\"")
    fi
  done

  local found_json
  found_json=$(IFS=,; echo "${found[*]:-}")
  local missing_json
  missing_json=$(IFS=,; echo "${missing[*]:-}")

  echo "{\"found\":[$found_json],\"missing\":[$missing_json]}"
}

# ── 전체 프로시저/트리거 요약 ──
# args: project_root profile
# stdout: JSON 객체 {procedure_count, procedure_sample, trigger_count}
collect_procedure_summary() {
  local root="$1"
  local profile="${2:-ehr4}"
  local mapper_ext
  mapper_ext=$(_mapper_ext "$profile")

  # 모든 P_/PKG_ 호출 추출
  local all_procs
  all_procs=$(grep -rhoE "\b(P_[A-Z][A-Z0-9_]+|PKG_[A-Z][A-Z0-9_]+)\b" --include="$mapper_ext" --include="*.xml" "$root" 2>/dev/null | sort -u)

  local proc_count
  proc_count=$(echo "$all_procs" | grep -c . || echo 0)
  [ -z "$proc_count" ] && proc_count=0

  # 상위 20개 샘플
  local sample=()
  while IFS= read -r p; do
    [ -n "$p" ] && sample+=("\"$p\"")
  done < <(echo "$all_procs" | head -20)

  local sample_json
  sample_json=$(IFS=,; echo "${sample[*]:-}")

  # 트리거 카운트 (TRG_)
  local trig_count
  trig_count=$(grep -rhoE "\bTRG_[A-Z][A-Z0-9_]+\b" --include="$mapper_ext" --include="*.xml" --include="*.java" "$root" 2>/dev/null | sort -u | grep -c . || echo 0)
  [ -z "$trig_count" ] && trig_count=0

  echo "{\"procedure_count\":$proc_count,\"procedure_sample\":[$sample_json],\"trigger_count\":$trig_count}"
}
