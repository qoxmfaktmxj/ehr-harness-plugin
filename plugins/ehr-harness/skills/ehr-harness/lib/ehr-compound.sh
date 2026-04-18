#!/usr/bin/env bash
# ehr-compound.sh — EHR 마커 블록 머지 헬퍼
#
# 외부 API:
#   ehr_marker_count     <file> <domain> <id>    -> "<begin_count> <end_count>"
#   ehr_marker_find_range <file> <domain> <id>   -> "<begin> <end>" (없으면 빈 문자열)
#   ehr_marker_exists    <file> <domain> <id>    -> 0/1
#   ehr_compound_upsert  <file> <domain> <id> <content>  (corrupt 시 abort)
#   ehr_compound_remove  <file> <domain> <id>
#   ehr_compound_list    <file> <domain>         -> id 목록 stdout
#
# 불변식 1 보호: upsert 는 BEGIN/END 개수가 각각 1:1 이거나 0:0 일 때만 동작.
# 그 외(예: 2 BEGIN + 1 END, 1 BEGIN + 0 END)는 corruption 으로 판정해 abort.
# 이유: head -1 로 첫 쌍을 잡아 sed 범위 삭제하면 마커 외부 사용자 prose 가 말소될 수 있음.

set -u

# 해당 id 의 BEGIN/END 마커 개수 echo (공백 구분)
ehr_marker_count() {
  local file="$1" domain="$2" id="$3"
  local b e
  b=$(grep -c "<!-- ${domain}:BEGIN ${id} " "$file" 2>/dev/null || true)
  # "BEGIN id " 뒤에 공백(속성/`-->`)이 올 수 있으므로 trailing 문자 구분
  local b_with_gt
  b_with_gt=$(grep -c "<!-- ${domain}:BEGIN ${id} -->" "$file" 2>/dev/null || true)
  # 속성 있는 형태 + 속성 없는 형태 모두 카운트
  b=$((b + b_with_gt))
  # 단, 위 두 패턴이 겹칠 수 있어 정확한 카운트는 BEGIN 라인을 한 번에 매치
  b=$(grep -cE "<!-- ${domain}:BEGIN ${id}([ ]|$)" "$file" 2>/dev/null || true)
  e=$(grep -cE "<!-- ${domain}:END ${id}([ ]|$)" "$file" 2>/dev/null || true)
  echo "${b:-0} ${e:-0}"
}

# 주어진 마커의 시작/종료 라인 번호 echo (없으면 빈 문자열)
# 전제: ehr_marker_count 가 1:1 이어야 안전. 그 외 상태에서는 호출하지 말 것.
ehr_marker_find_range() {
  local file="$1" domain="$2" id="$3"
  local begin end
  begin=$(grep -nE "<!-- ${domain}:BEGIN ${id}([ ]|$)" "$file" 2>/dev/null | head -1 | cut -d: -f1)
  end=$(grep -nE "<!-- ${domain}:END ${id}([ ]|$)" "$file" 2>/dev/null | head -1 | cut -d: -f1)
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
# 마커 corruption(카운트 불일치) 감지 시 abort. 불변식 1 보호.
ehr_compound_upsert() {
  local file="$1" domain="$2" id="$3" content="$4"

  # 파일이 없으면 빈 파일로 초기화 (touch). cat 오류 방지.
  if [[ ! -f "$file" ]]; then
    mkdir -p "$(dirname "$file")"
    touch "$file"
  fi

  # 마커 카운트 검증 (불변식 1)
  local counts b_cnt e_cnt
  counts=$(ehr_marker_count "$file" "$domain" "$id")
  b_cnt=$(echo "$counts" | awk '{print $1}')
  e_cnt=$(echo "$counts" | awk '{print $2}')
  if [[ "$b_cnt" != "$e_cnt" ]] || [[ "$b_cnt" != "0" && "$b_cnt" != "1" ]]; then
    echo "ERROR: ehr_compound_upsert: 마커 corruption 감지 — ${file} (${domain}:${id}, BEGIN=${b_cnt} END=${e_cnt})" >&2
    echo "ERROR: /ehr:compound --reindex 로 복구하거나 수동 정정 후 다시 시도하세요." >&2
    return 2
  fi

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
