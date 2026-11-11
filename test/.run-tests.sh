#!/usr/bin/env bash
# Discovers every test script (*.sh) in this directory and its subdirectories
# (one per feature, e.g. test/agent-cost-attribute/), and runs each one in
# turn, continuing past failures, then prints a summary. Exits non-zero if
# any test failed. Dotfiles (like this script and .lib.sh) are skipped.
#
# Usage: bash test/.run-tests.sh [<test directory or file>...]
#   e.g. bash test/.run-tests.sh test/add-prefix-to-pr
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ $# -eq 0 ] && set -- "$TEST_DIR"

tests=()
for target in "$@"; do
  if [ ! -e "$target" ]; then
    echo "No such test directory or file: $target" >&2
    exit 1
  fi
  # bash 3.2 (macOS) has no mapfile nor globstar.
  while IFS= read -r test; do
    tests+=("$(cd "$(dirname "$test")" && pwd)/$(basename "$test")")
  done < <(find "$target" -type f -name '*.sh' ! -name '.*' | sort)
done

if [ ${#tests[@]} -eq 0 ]; then
  echo "No tests found in: $*" >&2
  exit 1
fi

passed=()
failed=()

for test in "${tests[@]}"; do
  name="${test#"$TEST_DIR"/}"
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
