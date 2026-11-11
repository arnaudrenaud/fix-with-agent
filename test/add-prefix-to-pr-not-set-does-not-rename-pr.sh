#!/usr/bin/env bash
# Verifies that when add-prefix-to-pr is not passed, the action leaves the
# pull request title alone, even though the agent's fix was pushed to a branch
# with an open PR. Uses a stub gh (branch has PR #42), a stub agent that edits
# a tracked file, a success-check that always passes, and a real local bare
# repo as `origin`.
#
# Usage: bash test/add-prefix-to-pr-not-set-does-not-rename-pr.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/.lib.sh"

setup_fixture prefix-not-set-branch
write_workflow test-prefix-not-set <<'EOF'
success-check: "true"
commit-title: "fix: stub fix"
agent-command: |
  echo "fixed" > file.txt
  echo '{"result":"stub ran"}'
EOF
init_fixture_repo --with-origin

run_log="$(run_act 2>&1)" || true
echo "$run_log" | grep -E "⭐ Run Main|✅|❌|stub gh called|title set to"

echo
check "the whole job succeeds" \
  'echo "$run_log" | grep -q "🏁  Job succeeded"'
check "the fix was pushed to the branch, which has a PR" \
  'git --git-dir="$FIXTURE/.test-origin.git" log -1 --pretty=%B "$WORK_BRANCH" | grep -q "fix: stub fix" &&
   echo "$run_log" | grep -q "stub: pr comment on #42 suppressed"'
check "the prefix step does not run" \
  '! echo "$run_log" | grep -q "Run Main Add prefix to pull request title"'
check "the pull request title is neither read nor changed" \
  '! echo "$run_log" | grep -qE "stub gh called: api|title set to"'

finish
