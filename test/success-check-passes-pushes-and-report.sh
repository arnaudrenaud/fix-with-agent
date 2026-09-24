#!/usr/bin/env bash
# Verifies that when success-check passes after the agent's changes, the
# action commits them, pushes them to the remote, and writes the report to
# the job summary and posts it on the branch's PR. Uses a stub agent that
# edits a tracked file, a success-check that always passes, and a real local
# bare repo as `origin`, so an actual push can be verified without reaching
# any real remote.
#
# Usage: bash test/success-check-passes-pushes-and-report.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/.lib.sh"

setup_fixture success-check-passes-branch
write_workflow test-success-check-passes <<'EOF'
success-check: "true"
commit-title: "fix: stub fix"
agent-command: |
  echo "fixed" > file.txt
  printf 'stub agent report\nsecond line\n' > "$RUNNER_TEMP/fix-with-agent-report.md"
  echo '{"result":"stub ran","total_cost_usd":0.01}'
EOF
init_fixture_repo --with-origin

run_log="$(run_act 2>&1)" || true
echo "$run_log" | grep -E "⭐ Run Main|✅|❌|proceed=|has_changes="

echo
check "success check step runs and succeeds" \
  'echo "$run_log" | grep -q "✅  Success - Main Stop if success check still fails"'
check "commit and push step runs and succeeds" \
  'echo "$run_log" | grep -q "✅  Success - Main Commit and push changes, if any"'
check "report step runs and succeeds" \
  'echo "$run_log" | grep -q "✅  Success - Main $REPORT_STEP"'

check "a new commit with the fix landed in the local working repo" \
  'git -C "$FIXTURE" log -1 --pretty=%B | grep -q "fix: stub fix"'
check "that commit was actually pushed to origin, on the expected branch" \
  'git --git-dir="$FIXTURE/.test-origin.git" log -1 --pretty=%B "$WORK_BRANCH" | grep -q "fix: stub fix"'
check "the report was posted (stub gh pr comment was called on the branch's PR)" \
  'echo "$run_log" | grep -q "stub: pr comment on #42 suppressed"'

check "the full report was written to the job summary too" \
  'job_summary "$run_log" | grep -q "## Agent run report" &&
   job_summary "$run_log" | grep -q "stub agent report" &&
   job_summary "$run_log" | grep -q "second line"'

check "the full report is exposed as the action's \`report\` output too" \
  'echo "$run_log" | grep -q "report output: stub agent report" &&
   echo "$run_log" | grep -q "report output: second line"'

finish
