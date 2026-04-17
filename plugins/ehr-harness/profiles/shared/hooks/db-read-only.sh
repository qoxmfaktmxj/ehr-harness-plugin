#!/bin/bash
# db-read-only.sh — DB 직접 접근 시 SELECT만 허용
# PreToolUse (Bash) 훅: DROP, TRUNCATE, DELETE, UPDATE, INSERT, MERGE, ALTER, CREATE, GRANT, REVOKE, EXEC, CALL, UPSERT, DBMS_, UTL_, DECLARE/BEGIN/END, @script 차단
#
# Fail-closed 원칙: 훅 스크립트 내부 에러 발생 시 exit 2 (차단) — 정상 통과는 명시적 exit 0 만.
# (grep 미매치 exit 1 같은 예상 가능한 실패는 `|| true` 또는 `if`로 감싸므로 ERR trap 은 진짜 버그만 캐치)

set -u -o pipefail
trap 'echo "⛔ db-read-only 훅 내부 에러 — 안전을 위해 차단" >&2; exit 2' ERR

INPUT=$(cat)

# JSON 파싱: jq 우선, 없으면 node.js fallback
if command -v jq >/dev/null 2>&1; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
else
  COMMAND=$(echo "$INPUT" | node -e "let s='';process.stdin.on('data',d=>s+=d);process.stdin.on('end',()=>{try{const m=JSON.parse(s);process.stdout.write(m.tool_input?.command||'');}catch(e){}})" 2>/dev/null)
fi

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Step 1: SQL 실제 실행 명령 감지 (파일 텍스트 조작/보기는 제외)
#   - sqlplus, sqlcl, sqlcmd: Oracle/Tibero CLI
#   - impdp/expdp/rman: Oracle 데이터펌프/백업 도구
#   - 리다이렉트 파이프로 SQL 주입: `echo ... | sqlplus` / `cat f.sql | sqlplus`
# 이 단계에 매치 안 되면 통과 (grep, cat, ls *.sql 등은 여기서 빠짐)
if ! echo "$COMMAND" | grep -iqE '(\bsqlplus\b|\bsqlcl\b|\bsqlcmd\b|\bimpdp\b|\bexpdp\b|\brman\b|\btibero\b|\btbsql\b)'; then
  exit 0
fi

# Step 2: @script.sql 파일 실행 차단 (파일 내용 미확인 — 보수적 차단)
if echo "$COMMAND" | grep -qE '@[^ 	]*\.sql\b'; then
  echo "⛔ SQL 스크립트 파일 (@script.sql) 실행 차단" >&2
  echo "   스크립트 내용 자동 검증 불가 — 사용자가 직접 실행하세요." >&2
  exit 2
fi

# Step 3: DML/DDL/PL-SQL/시스템 패키지 키워드 감지
# 위치 무관 (첫 줄/중간/서브쿼리) — CTE+UPDATE, DECLARE BEGIN END 같은 우회 차단
# 키워드:
#   DML/DDL: DROP, TRUNCATE, DELETE, UPDATE, INSERT, MERGE, ALTER, CREATE, GRANT, REVOKE, UPSERT
#   Execution: EXEC, EXECUTE, CALL
#   PL/SQL block: DECLARE, BEGIN (END 단독은 ambiguous — 제외)
#   System packages: DBMS_*, UTL_*
# 주의: 문자열/주석 내부 false positive 가능하나 보안 우선 (발생 시 사용자가 따옴표/LIKE 회피)
DANGEROUS=$(echo "$COMMAND" | grep -ioE '\b(DROP|TRUNCATE|DELETE|UPDATE|INSERT|MERGE|ALTER|CREATE|GRANT|REVOKE|UPSERT|EXEC|EXECUTE|CALL|DECLARE|BEGIN|DBMS_[A-Z_]+|UTL_[A-Z_]+)\b' | head -1 || true)

if [ -n "$DANGEROUS" ]; then
  echo "⛔ DB 변경/실행 SQL 감지: ${DANGEROUS}" >&2
  echo "   조회(SELECT/WITH/EXPLAIN/DESC)만 허용됩니다." >&2
  echo "   프로시저/함수/더미 데이터는 사용자가 직접 생성하세요." >&2
  echo "   AI는 SQL 스크립트를 파일로 작성할 수 있습니다 (실행은 사용자 수동)." >&2
  exit 2
fi

exit 0
