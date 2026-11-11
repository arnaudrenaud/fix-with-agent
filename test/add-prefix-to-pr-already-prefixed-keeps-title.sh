#!/usr/bin/env bash
# Verifies that when the pull request title already starts with
# add-prefix-to-pr (e.g. the action already ran on this branch), the action
# does not add the prefix a second time. Uses a stub gh (branch has PR #42,
# already prefixed), a stub agent that edits a tracked file, a success-check
# that always passes, and a real local bare repo as `origin`.
#
# Usage: bash test/add-prefix-to-pr-already-prefixed-keeps-title.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/.lib.sh"

setup_fixture prefix-already-branch
STUB_PR_TITLE="⚠️ [fixed-with-agent] Stub PR title"
write_workflow test-prefix-already <<'EOF'
success-check: "true"
commit-title: "fix: stub fix"
add-prefix-to-pr: "⚠️ [fixed-with-agent] "
agent-command: |
  echo "fixed" > file.txt
  echo '{"result":"stub ran"}'
EOF
init_fixture_repo --with-origin

run_log="$(run_act 2>&1)" || true
echo "$run_log" | grep -E "⭐ Run Main|✅|❌|stub gh called|title set to|already starts"

echo
check "the prefix step runs and succeeds" \
  'echo "$run_log" | grep -q "✅  Success - Main Add prefix to pull request title"'
check "it notices the title already has the prefix" \
  'echo "$run_log" | grep -q "Pull request #42 title already starts with the prefix."'
check "the PR title is left unchanged" \
  '! echo "$run_log" | grep -q "title set to"'

finish
