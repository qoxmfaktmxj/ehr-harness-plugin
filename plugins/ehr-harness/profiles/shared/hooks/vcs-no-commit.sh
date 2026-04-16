#!/bin/bash
# vcs-no-commit.sh — AI의 VCS commit/push 차단
# 사용자가 직접 변경 내용을 확인하고 커밋해야 합니다.

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

# git commit, push, rebase, reset, revert, tag 차단
if echo "$COMMAND" | grep -iqE '\bgit\s+(commit|push|rebase|reset|revert|tag)\b'; then
  echo "⛔ Git 커밋/푸시 차단"
  echo "AI는 코드 수정까지만 수행합니다."
  echo "변경 내용을 직접 확인한 후 수동으로 커밋/푸시하세요."
  exit 2
fi

# svn commit, ci, import, copy, move, delete, mkdir, merge 차단
if echo "$COMMAND" | grep -iqE '\bsvn\s+(commit|ci|import|copy|move|delete|rm|mkdir|merge)\b'; then
  echo "⛔ SVN 커밋/변경 차단"
  echo "AI는 코드 수정까지만 수행합니다."
  echo "변경 내용을 직접 확인한 후 수동으로 커밋하세요."
  exit 2
fi

exit 0
