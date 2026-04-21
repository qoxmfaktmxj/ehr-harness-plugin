#!/usr/bin/env bash
# db.sh — DB 접속 테스트 + 덤프 폴더 포맷 감지
#
# SKILL.md Step 2-J 에서 사용:
#   source db.sh
#   test_db_connection "$DB_CONNECTION"
#   detect_dump_format "$DUMP_DIR"
#   redact_connection_string "$DB_CONNECTION"
#
# 설계 원칙:
# - 드라이버(sqlplus/tbsql)가 PATH 에 없어도 명확히 실패 리턴. 자동 fallback 금지.
# - password 는 stdout/stderr 어디에도 평문 노출 금지. 로그는 redact 처리.
# - 덤프 포맷 판정은 디렉토리 구조만 본다 (바이너리 파싱 금지).

set -u

# ── 커넥션 문자열에서 password 부분을 마스킹 ──
# 지원 패턴:
#   1) jdbc:<vendor>:thin:user/password@host:port:sid (또는 /SID)
#   2) user/password@host:port/sid
#   3) password=<value> 또는 pwd=<value> 쿼리 파라미터
# stdout: 마스킹된 문자열
redact_connection_string() {
  local s="${1:-}"
  # user/pass@host → user/***@host
  # password 안에 '/' 가 포함된 경우(임시 패스워드 관행) 일부만 가려지지 않도록
  # '/' 는 class 에서 제외하지 않고 '@' 까지 greedy 하게 잡는다.
  s=$(printf '%s' "$s" | sed -E 's#/[^@[:space:]]+@#/***@#g')
  # password=xxx / pwd=xxx
  s=$(printf '%s' "$s" | sed -E 's#(password|pwd)=[^&[:space:]]*#\1=***#gi')
  printf '%s\n' "$s"
}

# ── 접속 문자열에서 벤더 감지 ──
# stdout: oracle | tibero | unknown
_detect_vendor() {
  local s="${1:-}"
  case "$s" in
    *jdbc:tibero:*|*tibero:*) echo "tibero" ;;
    *jdbc:oracle:*|*oracle:thin:*) echo "oracle" ;;
    *) echo "unknown" ;;
  esac
}

# ── CLI 드라이버 존재 확인 ──
# args: oracle|tibero
# return code: 0 = 있음, 1 = 없음
# stdout: 실제 실행 파일 이름 (sqlplus 또는 tbsql) 또는 빈 문자열
_locate_db_cli() {
  local vendor="${1:-oracle}"
  case "$vendor" in
    tibero)
      if command -v tbsql >/dev/null 2>&1; then echo "tbsql"; return 0; fi
      ;;
    oracle|unknown)
      if command -v sqlplus >/dev/null 2>&1; then echo "sqlplus"; return 0; fi
      ;;
  esac
  echo ""
  return 1
}

# ── user/password@host:port/sid 형태로 정규화 ──
# input: JDBC URL 또는 이미 정규화된 문자열
# stdout: "user/password@host:port/sid" 형태 (파싱 실패 시 원본 반환)
_normalize_conn_for_cli() {
  local s="${1:-}"
  # jdbc:oracle:thin:user/pass@host:port:SID 또는 host:port/SID 패턴
  # log4jdbc: prefix 제거
  s="${s#log4jdbc:}"
  # jdbc:<vendor>:thin: prefix 제거
  s=$(printf '%s' "$s" | sed -E 's#^jdbc:[a-z]+:thin:##')
  # host:port:SID → host:port/SID (Oracle 구표기 호환)
  s=$(printf '%s' "$s" | sed -E 's#@([^:/@]+):([0-9]+):([A-Za-z0-9_.]+)$#@\1:\2/\3#')
  printf '%s\n' "$s"
}

# ── DB 연결 테스트 ──
# args: connection_string (JDBC URL 또는 user/pass@host:port/sid)
# exit code: 0 = 성공, 1 = 드라이버/접속 실패
# stdout: 성공 시 "OK <vendor> <cli>", 실패 시 사유 (password redact 됨)
test_db_connection() {
  local conn="${1:-}"
  if [ -z "$conn" ]; then
    echo "ERR: empty connection string" >&2
    return 1
  fi

  local vendor cli normalized redacted
  vendor=$(_detect_vendor "$conn")
  redacted=$(redact_connection_string "$conn")

  cli=$(_locate_db_cli "$vendor")
  if [ -z "$cli" ]; then
    echo "ERR: DB CLI not found on PATH (vendor=$vendor). install sqlplus/tbsql or switch to dump mode. conn=$redacted" >&2
    return 1
  fi

  normalized=$(_normalize_conn_for_cli "$conn")

  # 실제 연결 — SELECT 결과 sentinel 로 성공 판정. banner 문자열에 우연히 "1"
  # 이 찍혀도 false positive 나지 않도록 구분자(`EHRDB_OK_SENTINEL`) 사용.
  # 접속 문자열은 argv 로 넘기지 않고 /nolog 모드에서 stdin CONNECT 로 주입 —
  # `ps` / audit log 로 평문 password 가 노출되는 위험 차단.
  local script
  script="WHENEVER SQLERROR EXIT FAILURE
CONNECT $normalized
SELECT 'EHRDB_OK_SENTINEL' FROM DUAL;
EXIT;"

  local out=""
  local rc=0
  if [ "$cli" = "sqlplus" ]; then
    out=$(printf '%s\n' "$script" | "$cli" -S -L /nolog 2>&1) || rc=$?
  else
    # tbsql (Tibero) 도 Oracle 호환 /nolog + CONNECT 문법 지원
    out=$(printf '%s\n' "$script" | "$cli" -s /nolog 2>&1) || rc=$?
  fi

  # output 에 password 가 echo 되는 드라이버 대비 redact
  out=$(redact_connection_string "$out")

  if [ $rc -eq 0 ] && printf '%s' "$out" | grep -q 'EHRDB_OK_SENTINEL'; then
    echo "OK $vendor $cli"
    return 0
  fi

  echo "ERR: $cli connection failed (rc=$rc) conn=$redacted detail=$(printf '%s' "$out" | head -3 | tr '\n' ';')" >&2
  return 1
}

# ── 덤프 폴더 포맷 감지 ──
# args: dump_dir
# stdout: F1 | F2 | F3 | F4 | F5 | unknown
# return code: 0 (언제나 stdout 으로 결과 전달). dir 없으면 "unknown" + rc=1.
#   F1: 단일 SQL 파일 (디렉토리 내 .sql 1개 또는 root 한 파일)
#   F2: 객체 타입별 서브폴더 (tables/ procedures/ packages/ functions/ triggers/ 중 2+)
#   F3: 한 폴더에 객체 타입별 접두어 파일이 섞여 있음 (T_* P_* PKG_* F_* TRG_*)
#   F4: Toad/SQL Developer 익스포트 (Tables/ Stored_Procedures/ 등 카테고리명 서브폴더)
#   F5: 바이너리 덤프 (.dmp 파일 존재)
detect_dump_format() {
  local dir="${1:-}"
  if [ -z "$dir" ] || [ ! -d "$dir" ]; then
    echo "unknown"
    return 1
  fi

  # F5: .dmp 파일 존재
  if find "$dir" -maxdepth 3 -type f -iname '*.dmp' 2>/dev/null | grep -q .; then
    echo "F5"
    return 0
  fi

  # 실제 서브디렉토리 이름 (Windows 파일시스템은 case-insensitive 하므로
  # `[ -d "$dir/tables" ]` 만으로는 `Tables/` 도 hit 한다. 이를 피하기 위해
  # find 결과를 literal 문자열로 매칭한다.)
  local dnames
  dnames=$(find "$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sed 's|.*/||')

  # F4: Toad/SQL Developer 익스포트 — 언더스코어가 포함된 카테고리명이 시그니처
  local f4_hits=0
  local sub
  for sub in Stored_Procedures Sequences Synonyms Materialized_Views Package_Bodies; do
    printf '%s\n' "$dnames" | grep -qx "$sub" && f4_hits=$((f4_hits + 1))
  done
  if [ $f4_hits -ge 1 ]; then
    echo "F4"
    return 0
  fi

  # F2: 소문자 표준 서브폴더
  local f2_hits=0
  for sub in tables procedures packages functions triggers; do
    printf '%s\n' "$dnames" | grep -qx "$sub" && f2_hits=$((f2_hits + 1))
  done
  if [ $f2_hits -ge 2 ]; then
    echo "F2"
    return 0
  fi

  # F3: 루트에 객체 접두어 파일이 섞여 있음 (최소 2가지 타입 + 최소 3개 파일)
  local prefix_types=0 total_prefixed=0
  local pat
  for pat in 'T_*.sql' 'P_*.sql' 'PKG_*.sql' 'PKG_*.pkb' 'F_*.sql' 'TRG_*.sql'; do
    local cnt
    cnt=$(find "$dir" -maxdepth 1 -type f -name "$pat" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$cnt" -gt 0 ]; then
      prefix_types=$((prefix_types + 1))
      total_prefixed=$((total_prefixed + cnt))
    fi
  done
  if [ $prefix_types -ge 2 ] && [ $total_prefixed -ge 3 ]; then
    echo "F3"
    return 0
  fi

  # F1: 단일 SQL 파일 (또는 극소수만 있음)
  local sql_cnt
  sql_cnt=$(find "$dir" -maxdepth 2 -type f -name '*.sql' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$sql_cnt" -ge 1 ] && [ "$sql_cnt" -le 3 ]; then
    echo "F1"
    return 0
  fi

  echo "unknown"
  return 0
}
