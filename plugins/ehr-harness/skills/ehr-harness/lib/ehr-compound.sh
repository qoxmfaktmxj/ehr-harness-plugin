#!/usr/bin/env bash
# ehr-compound.sh — EHR 마커 블록 머지 헬퍼
#
# 외부 API:
#   ehr_marker_find_range <file> <domain> <id>   -> "<begin> <end>" (없으면 빈 문자열)
#   ehr_marker_exists <file> <domain> <id>       -> 0/1
#   ehr_compound_upsert <file> <domain> <id> <content>
#   ehr_compound_remove <file> <domain> <id>
#   ehr_compound_list   <file> <domain>          -> id 목록 stdout

set -u

# 주어진 마커의 시작/종료 라인 번호 echo (없으면 빈 문자열)
ehr_marker_find_range() {
  local file="$1" domain="$2" id="$3"
  local begin end
  begin=$(grep -n "<!-- ${domain}:BEGIN ${id}" "$file" 2>/dev/null | head -1 | cut -d: -f1)
  end=$(grep -n "<!-- ${domain}:END ${id}" "$file" 2>/dev/null | head -1 | cut -d: -f1)
  if [[ -n "$begin" && -n "$end" ]]; then
    echo "$begin $end"
  fi
}

ehr_marker_exists() {
  local r
  r=$(ehr_marker_find_range "$@")
  [[ -n "$r" ]]
}

# 블록 삽입/업데이트. 기존 id 있으면 덮어쓰고, 없으면 파일 말미에 추가.
ehr_compound_upsert() {
  local file="$1" domain="$2" id="$3" content="$4"
  local begin end range
  range=$(ehr_marker_find_range "$file" "$domain" "$id")
  if [[ -n "$range" ]]; then
    begin=$(echo "$range" | awk '{print $1}')
    end=$(echo "$range" | awk '{print $2}')
    local tmp
    tmp=$(mktemp)
    {
      sed -n "1,$((begin-1))p" "$file"
      printf '<!-- %s:BEGIN %s -->\n%s\n<!-- %s:END %s -->\n' \
        "$domain" "$id" "$content" "$domain" "$id"
      sed -n "$((end+1)),\$p" "$file"
    } > "$tmp"
    mv "$tmp" "$file"
  else
    # 파일 말미에 빈 줄 하나(separator) + 블록 추가
    # 파일이 개행 없이 끝나면 먼저 개행 보정 후 separator 추가
    local tmp
    tmp=$(mktemp)
    {
      cat "$file"
      # 마지막 바이트가 개행이 아니면 개행 한 번 보정
      [[ -z "$(tail -c1 "$file")" ]] || echo ""
      # separator 빈 줄
      echo ""
      printf '<!-- %s:BEGIN %s -->\n%s\n<!-- %s:END %s -->\n' \
        "$domain" "$id" "$content" "$domain" "$id"
    } > "$tmp"
    mv "$tmp" "$file"
  fi
}

# 블록 제거. 없으면 아무 일도 안 함.
ehr_compound_remove() {
  local file="$1" domain="$2" id="$3"
  local range begin end
  range=$(ehr_marker_find_range "$file" "$domain" "$id")
  [[ -z "$range" ]] && return 0
  begin=$(echo "$range" | awk '{print $1}')
  end=$(echo "$range" | awk '{print $2}')
  local tmp
  tmp=$(mktemp)
  {
    sed -n "1,$((begin-1))p" "$file"
    sed -n "$((end+1)),\$p" "$file"
  } > "$tmp"
  mv "$tmp" "$file"
}

# 주어진 도메인의 모든 id 목록을 한 줄에 하나씩 출력.
ehr_compound_list() {
  local file="$1" domain="$2"
  grep -oE "<!-- ${domain}:BEGIN [A-Za-z0-9_-]+" "$file" 2>/dev/null \
    | sed "s|<!-- ${domain}:BEGIN ||"
}
