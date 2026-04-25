#!/usr/bin/env bash
# Integrated test runner for ehr-harness plugin.
#
# 수집 범위:
#   - skills/ehr-harness/lib/*.test.sh (평면)
#   - skills/ehr-harness/lib/tests/*.test.sh (서브)
#   - profiles/shared/hooks/*.test.sh (hook 회귀)
#
# NOTE: -e 제외 — 개별 테스트 실패 시에도 루프를 계속 돌려 FAIL 카운터로 수집.
set -uo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ROOT="$(cd "$LIB_DIR/../../.." && pwd)"
HOOKS_DIR="$PLUGIN_ROOT/profiles/shared/hooks"

PASS=0; FAIL=0; FAILED_FILES=()

# 1) lib/ 평면 + lib/tests/ 서브
mapfile -t LIB_FILES < <(find "$LIB_DIR" -maxdepth 2 -name '*.test.sh' -type f | sort)
# 2) profiles/shared/hooks/
mapfile -t HOOK_FILES < <(find "$HOOKS_DIR" -maxdepth 1 -name '*.test.sh' -type f 2>/dev/null | sort)

FILES=("${LIB_FILES[@]}" "${HOOK_FILES[@]}")

for f in "${FILES[@]}"; do
  echo "=== $f ==="
  if bash "$f"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    FAILED_FILES+=("$f")
  fi
done

echo "------------------------------------------------------------"
echo "Total files: $((PASS+FAIL))  Pass: $PASS  Fail: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed files:"
  printf '  - %s\n' "${FAILED_FILES[@]}"
  exit 1
fi
exit 0
