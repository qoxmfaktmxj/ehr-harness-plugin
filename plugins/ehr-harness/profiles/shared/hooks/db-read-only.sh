#!/bin/bash
# db-read-only.sh — DB 직접 접근 시 SELECT만 허용
# PreToolUse (Bash) 훅: DROP, TRUNCATE, DELETE, UPDATE, INSERT, MERGE, ALTER, CREATE, GRANT, REVOKE, EXEC, CALL, UPSERT, DBMS_ 차단

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

# sqlplus, sql 관련 명령인지 확인
if echo "$COMMAND" | grep -iqE '(sqlplus|sql\s|oracle|--execute|\.sql)'; then
  # 위험 SQL 키워드 검사 (주석/문자열 내부 오탐 가능성 있으나 안전 우선)
  DANGEROUS=$(echo "$COMMAND" | grep -ioE '\b(DROP|TRUNCATE|DELETE|UPDATE|INSERT|MERGE|ALTER|CREATE|GRANT|REVOKE|EXEC|EXECUTE|CALL|UPSERT|DBMS_)\b' | head -1)

  if [ -n "$DANGEROUS" ]; then
    # SELECT 문 안의 서브쿼리가 아닌 단독 DML/DDL인지 확인
    # SELECT 전용 쿼리는 통과
    IS_SELECT_ONLY=$(echo "$COMMAND" | grep -icE '^\s*(SELECT|WITH|EXPLAIN|DESC|SHOW)\b')

    if [ "$IS_SELECT_ONLY" -eq 0 ] 2>/dev/null; then
      echo "⛔ DB 변경 SQL 감지: ${DANGEROUS}"
      echo "조회(SELECT)만 허용됩니다."
      echo "프로시저/함수/더미 데이터는 사용자가 직접 생성하세요."
      echo "AI는 SQL 스크립트를 파일로 작성할 수 있습니다."
      exit 2
    fi
  fi
fi

exit 0
