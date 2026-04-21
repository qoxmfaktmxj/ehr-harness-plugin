#!/usr/bin/env bash
# db.test.sh — DB helper 테스트
#
# 실행: bash db.test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/db.sh"

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; }

# ── 임시 fixture 디렉토리 (테스트 종료 시 정리) ──
TMP_ROOT=$(mktemp -d 2>/dev/null || mktemp -d -t 'ehrdb')
trap 'rm -rf "$TMP_ROOT"' EXIT

# ── redact_connection_string ──
RESULT=$(redact_connection_string "jdbc:oracle:thin:scott/tiger@localhost:1521:ORCL")
case "$RESULT" in
  *"scott/***@"*) pass "redact: jdbc user/pass 마스킹" ;;
  *) fail "redact: jdbc user/pass 마스킹 안됨 ($RESULT)" ;;
esac
case "$RESULT" in
  *tiger*) fail "redact: password 평문 잔존 ($RESULT)" ;;
  *) pass "redact: password 평문 제거" ;;
esac

RESULT=$(redact_connection_string "host=db.local;user=hrm;password=s3cret!;port=1521")
case "$RESULT" in
  *"password=***"*) pass "redact: password= 쿼리 파라미터 마스킹" ;;
  *) fail "redact: password= 마스킹 안됨 ($RESULT)" ;;
esac
case "$RESULT" in
  *"s3cret!"*) fail "redact: password= 평문 잔존 ($RESULT)" ;;
  *) pass "redact: password= 평문 제거" ;;
esac

RESULT=$(redact_connection_string "user/qwer1234@10.0.0.5:1521/HRM")
case "$RESULT" in
  *"user/***@"*) pass "redact: 비-JDBC 표기도 마스킹" ;;
  *) fail "redact: 비-JDBC 표기 마스킹 안됨 ($RESULT)" ;;
esac

# ── slash 포함 password 전체 마스킹 (P1-2 회귀 테스트) ──
RESULT=$(redact_connection_string "scott/ti/ger@host:1521:ORCL")
case "$RESULT" in
  *"scott/***@"*) pass "redact: slash 포함 pw 전체 마스킹" ;;
  *) fail "redact: slash 포함 pw 마스킹 불완전 ($RESULT)" ;;
esac
case "$RESULT" in
  *"ti/ger"*|*"ti/"*) fail "redact: slash pw 일부 평문 잔존 ($RESULT)" ;;
  *) pass "redact: slash pw 일부 잔존 없음" ;;
esac

# ── _normalize_conn_for_cli: 정상 입력은 stderr silent (P2-1 정상 경로) ──
STDERR=$(_normalize_conn_for_cli "scott/tiger@localhost:1521:ORCL" 2>&1 >/dev/null)
[ -z "$STDERR" ] \
  && pass "normalize: placeholder 없으면 stderr silent" \
  || fail "normalize: 정상 경로에서 stderr 발생 ($STDERR)"

# ── _normalize_conn_for_cli: Oracle 식별자·password 안의 '$' 는 false positive 안 나야 함 ──
# (SCOTT$SCHEMA, SYS$UMF 같은 시스템/레거시 유저, password 에 '$' 포함 등)
STDERR=$(_normalize_conn_for_cli 'SCOTT$SCHEMA/pass@host:1521:ORCL' 2>&1 >/dev/null)
[ -z "$STDERR" ] \
  && pass "normalize: user '\$' 포함 식별자 false positive 없음" \
  || fail "normalize: user '\$' 식별자에서 false positive WARN ($STDERR)"
STDERR=$(_normalize_conn_for_cli 'scott/pa$w0rd@host:1521:ORCL' 2>&1 >/dev/null)
[ -z "$STDERR" ] \
  && pass "normalize: password 내 '\$' false positive 없음" \
  || fail "normalize: password '\$' 에서 false positive WARN ($STDERR)"

# ── _normalize_conn_for_cli: ${VAR} 미치환 placeholder → stderr WARN + 토큰 포함 ──
STDERR=$(_normalize_conn_for_cli 'scott/tiger@${DB_HOST}:1521:ORCL' 2>&1 >/dev/null)
case "$STDERR" in
  *WARN*unresolved*placeholder*'${DB_HOST}'*) pass "normalize: \${VAR} placeholder → WARN + 토큰 포함" ;;
  *) fail "normalize: \${VAR} WARN/토큰 누락 ($STDERR)" ;;
esac

# ── 여러 placeholder 가 있으면 모두 노출 (최대 3개) ──
STDERR=$(_normalize_conn_for_cli 'scott/tiger@${DB_HOST}:${DB_PORT}:${DB_SID}' 2>&1 >/dev/null)
case "$STDERR" in
  *'${DB_HOST}'*'${DB_PORT}'*'${DB_SID}'*) pass "normalize: 다중 placeholder 모두 노출" ;;
  *'${DB_SID}'*'${DB_PORT}'*'${DB_HOST}'*) pass "normalize: 다중 placeholder 모두 노출" ;;
  *) fail "normalize: 다중 placeholder 일부 누락 ($STDERR)" ;;
esac

# ── test_db_connection: 드라이버 없으면 즉시 실패 + password 미노출 ──
# sqlplus/tbsql 존재 여부와 무관하게 "비어있는 입력"은 반드시 실패
if test_db_connection "" 2>/dev/null; then
  fail "test_db_connection: 빈 입력인데 성공 리턴"
else
  pass "test_db_connection: 빈 입력 → 실패 리턴"
fi

# 드라이버 없는 가상 벤더 → "drivers not found" 경로
# (Windows/Linux 어디서 돌려도 mssql 용 CLI 는 없으니 실패가 보장됨)
OUT=$(test_db_connection "jdbc:sqlserver://user/topsecret@host:1433/db" 2>&1 || true)
case "$OUT" in
  *topsecret*) fail "test_db_connection: password 평문 노출 ($OUT)" ;;
  *) pass "test_db_connection: 실패 메시지에 password 미노출" ;;
esac
case "$OUT" in
  ERR:*) pass "test_db_connection: 실패 시 ERR: 프리픽스" ;;
  *) fail "test_db_connection: 에러 포맷에 ERR: 프리픽스 없음 ($OUT)" ;;
esac

# ── detect_dump_format: 없는 경로 ──
RESULT=$(detect_dump_format "/no/such/dir" 2>/dev/null || true)
[ "$RESULT" = "unknown" ] \
  && pass "detect_dump_format: 없는 경로 → unknown" \
  || fail "detect_dump_format: 없는 경로인데 결과=$RESULT"

# ── F5: .dmp 파일 존재 ──
mkdir -p "$TMP_ROOT/f5"
: > "$TMP_ROOT/f5/export.dmp"
RESULT=$(detect_dump_format "$TMP_ROOT/f5")
[ "$RESULT" = "F5" ] \
  && pass "detect_dump_format: F5 감지 (.dmp)" \
  || fail "detect_dump_format: F5 기대인데 $RESULT"

# ── F2: 타입별 서브폴더 ──
mkdir -p "$TMP_ROOT/f2/tables" "$TMP_ROOT/f2/procedures" "$TMP_ROOT/f2/packages"
: > "$TMP_ROOT/f2/tables/T_HRM001.sql"
: > "$TMP_ROOT/f2/procedures/P_CPN_CAL_PAY_MAIN.sql"
RESULT=$(detect_dump_format "$TMP_ROOT/f2")
[ "$RESULT" = "F2" ] \
  && pass "detect_dump_format: F2 감지 (타입별 서브폴더)" \
  || fail "detect_dump_format: F2 기대인데 $RESULT"

# ── F4: Toad 스타일 카테고리 서브폴더 ──
mkdir -p "$TMP_ROOT/f4/Tables" "$TMP_ROOT/f4/Stored_Procedures" "$TMP_ROOT/f4/Triggers"
: > "$TMP_ROOT/f4/Tables/T_EMP.sql"
RESULT=$(detect_dump_format "$TMP_ROOT/f4")
[ "$RESULT" = "F4" ] \
  && pass "detect_dump_format: F4 감지 (Toad 카테고리)" \
  || fail "detect_dump_format: F4 기대인데 $RESULT"

# ── F3: 접두어 혼재 ──
mkdir -p "$TMP_ROOT/f3"
: > "$TMP_ROOT/f3/T_HRM001.sql"
: > "$TMP_ROOT/f3/P_HRM_POST.sql"
: > "$TMP_ROOT/f3/TRG_AUDIT.sql"
RESULT=$(detect_dump_format "$TMP_ROOT/f3")
[ "$RESULT" = "F3" ] \
  && pass "detect_dump_format: F3 감지 (접두어 혼재)" \
  || fail "detect_dump_format: F3 기대인데 $RESULT"

# ── F1: 단일 SQL ──
mkdir -p "$TMP_ROOT/f1"
: > "$TMP_ROOT/f1/all_schema.sql"
RESULT=$(detect_dump_format "$TMP_ROOT/f1")
[ "$RESULT" = "F1" ] \
  && pass "detect_dump_format: F1 감지 (단일 SQL)" \
  || fail "detect_dump_format: F1 기대인데 $RESULT"

# ── unknown: sql 전혀 없음 ──
mkdir -p "$TMP_ROOT/un"
: > "$TMP_ROOT/un/readme.txt"
RESULT=$(detect_dump_format "$TMP_ROOT/un")
[ "$RESULT" = "unknown" ] \
  && pass "detect_dump_format: sql 없음 → unknown" \
  || fail "detect_dump_format: unknown 기대인데 $RESULT"

echo ""
echo "all db.test.sh passed"
