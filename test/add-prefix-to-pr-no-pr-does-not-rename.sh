#!/usr/bin/env bash
# Verifies that when add-prefix-to-pr is set but the branch has no open pull
# request, the action renames nothing — no PR title, no branch — and still
# pushes the fix to the branch as-is. Uses a stub gh that finds no PR, a stub
# agent that edits a tracked file, a success-check that always passes, and a
# real local bare repo as `origin`.
#
# Usage: bash test/add-prefix-to-pr-no-pr-does-not-rename.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/.lib.sh"

setup_fixture prefix-no-pr-branch
STUB_PR_NUMBER=""
write_workflow test-prefix-no-pr <<'EOF'
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
check "the whole job succeeds (no PR is not an error)" \
  'echo "$run_log" | grep -q "🏁  Job succeeded"'
check "the prefix step does not run" \
  '! echo "$run_log" | grep -q "Run Main Add prefix to pull request title"'
check "no pull request title is read or changed" \
  '! echo "$run_log" | grep -qE "stub gh called: api|title set to"'
check "the branch is not renamed: the fix was pushed to it, and origin has no other branch" \
  'git --git-dir="$FIXTURE/.test-origin.git" log -1 --pretty=%B "$WORK_BRANCH" | grep -q "fix: stub fix" &&
   [ "$(git --git-dir="$FIXTURE/.test-origin.git" for-each-ref --format="%(refname:short)" refs/heads)" = "$WORK_BRANCH" ]'

finish
