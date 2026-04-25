#!/bin/bash
# vcs-no-commit.sh — AI의 VCS commit/push 차단
# 사용자가 직접 변경 내용을 확인하고 커밋해야 합니다.
#
# Fail-closed 원칙: 훅 스크립트 내부 에러 발생 시 exit 2 (차단).
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

set -u -o pipefail
trap 'echo "⛔ vcs-no-commit 훅 내부 에러 — 안전을 위해 차단" >&2; exit 2' ERR

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

# git 커밋/히스토리/패치 관련 서브커맨드 차단
# - 직접 커밋: commit
# - 원격 반영: push
# - 히스토리 재작성: rebase, reset, revert, tag
# - 패치 적용 (간접 커밋 경로): apply, am, cherry-pick, format-patch
if echo "$COMMAND" | grep -iqE '\bgit\s+(commit|push|rebase|reset|revert|tag|apply|am|cherry-pick|format-patch)\b'; then
  echo "⛔ Git 커밋/푸시/패치 차단" >&2
  echo "   AI는 코드 수정까지만 수행합니다." >&2
  echo "   변경 내용을 직접 확인한 후 수동으로 커밋/푸시하세요." >&2
  exit 2
fi

# git stash pop / apply 차단 (파일 변경 반영 — 간접적 "commit-able 상태" 복원)
# - stash push, stash list, stash show 는 허용 (내용 저장/조회)
if echo "$COMMAND" | grep -iqE '\bgit\s+stash\s+(pop|apply)\b'; then
  echo "⛔ git stash pop/apply 차단 (파일 변경 반영)" >&2
  echo "   stash 내용 적용은 사용자가 직접 수행하세요." >&2
  exit 2
fi

# svn commit, ci, import, copy, move, delete, mkdir, merge 차단
if echo "$COMMAND" | grep -iqE '\bsvn\s+(commit|ci|import|copy|move|delete|rm|mkdir|merge)\b'; then
  echo "⛔ SVN 커밋/변경 차단" >&2
  echo "   AI는 코드 수정까지만 수행합니다." >&2
  echo "   변경 내용을 직접 확인한 후 수동으로 커밋하세요." >&2
  exit 2
fi

exit 0
