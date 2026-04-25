#!/usr/bin/env bash
# Integrated test runner for ehr-harness lib.
# Discovers all *.test.sh under lib/ (excluding node_modules) and runs them.
set -uo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$LIB_DIR/../../../.." && pwd)"

PASS=0; FAIL=0; FAILED_FILES=()

# 평면 lib/*.test.sh + tests/*.test.sh 모두 수집
mapfile -t FILES < <(find "$LIB_DIR" -maxdepth 2 -name '*.test.sh' -type f | sort)

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
echo "Total: $((PASS+FAIL))  Pass: $PASS  Fail: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed files:"
  printf '  - %s\n' "${FAILED_FILES[@]}"
  exit 1
fi
exit 0
