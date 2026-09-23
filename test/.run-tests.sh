#!/usr/bin/env bash
# Discovers every test script (*.sh) in this directory and runs each one in
# turn, continuing past failures, then prints a summary. Exits non-zero if
# any test failed. Dotfiles (like this script) are skipped by the glob.
#
# Usage: bash test/.run-tests.sh
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

shopt -s nullglob
tests=("$TEST_DIR"/*.sh)
shopt -u nullglob

if [ ${#tests[@]} -eq 0 ]; then
  echo "No tests found in $TEST_DIR" >&2
  exit 1
fi

passed=()
failed=()

for test in "${tests[@]}"; do
  name="$(basename "$test")"
  echo "=== RUN  $name"
  if bash "$test"; then
    echo "=== PASS $name"
    passed+=("$name")
  else
    echo "=== FAIL $name"
    failed+=("$name")
  fi
  echo
done

echo "=== Summary: ${#passed[@]} passed, ${#failed[@]} failed (of ${#tests[@]})"
# ${arr[@]+...} guards against "unbound variable" on empty arrays in bash 3.2
for name in ${failed[@]+"${failed[@]}"}; do
  echo "  FAIL $name"
done

[ ${#failed[@]} -eq 0 ]
