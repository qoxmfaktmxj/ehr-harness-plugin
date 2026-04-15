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
