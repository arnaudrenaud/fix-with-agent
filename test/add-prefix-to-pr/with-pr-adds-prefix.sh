#!/usr/bin/env bash
# Verifies that when add-prefix-to-pr is set and the agent's fix was pushed to
# a branch with an open pull request, the action prepends the prefix to the
# PR title, and does not rename the branch. Uses a stub gh (branch has PR #42,
# titled "Stub PR title"), a stub agent that edits a tracked file, a
# success-check that always passes, and a real local bare repo as `origin`.
#
# Usage: bash test/add-prefix-to-pr/with-pr-adds-prefix.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../.lib.sh"

setup_fixture prefix-with-pr-branch
write_workflow test-prefix-with-pr <<'EOF'
success-check: "true"
commit-title: "fix: stub fix"
add-prefix-to-pr: "⚠️ [fixed-with-agent] "
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
check "the prefix step runs and succeeds" \
  'echo "$run_log" | grep -q "✅  Success - Main Add prefix to pull request title"'
check "the PR title gets the prefix, trailing space included" \
  'echo "$run_log" | grep -qF "stub: pr #42 title set to: ⚠️ [fixed-with-agent] Stub PR title"'
check "the branch is not renamed: the fix was pushed to it, and origin has no other branch" \
  'git --git-dir="$FIXTURE/.test-origin.git" log -1 --pretty=%B "$WORK_BRANCH" | grep -q "fix: stub fix" &&
   [ "$(git --git-dir="$FIXTURE/.test-origin.git" for-each-ref --format="%(refname:short)" refs/heads)" = "$WORK_BRANCH" ]'
check "no gh call touches branches" \
  '! echo "$run_log" | grep "stub gh called: " | grep -q "branches"'

finish
