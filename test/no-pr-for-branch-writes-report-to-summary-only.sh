#!/usr/bin/env bash
# Verifies that when the branch has no open pull request, the action does not
# try to post the report anywhere but still writes it to the job summary, and
# the run succeeds (a missing PR is not an error). Uses a stub gh that finds
# no PR for the branch, a stub agent that edits a tracked file, a
# success-check that always passes, and a real local bare repo as `origin`.
#
# Usage: bash test/no-pr-for-branch-writes-report-to-summary-only.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/.lib.sh"

setup_fixture no-pr-branch
STUB_PR_NUMBER=""
write_workflow test-no-pr <<'EOF'
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
check "report step runs and succeeds" \
  'echo "$run_log" | grep -q "✅  Success - Main $REPORT_STEP"'
check "the whole job succeeds (no PR is not an error)" \
  'echo "$run_log" | grep -q "🏁  Job succeeded"'
check "the fix was still pushed to the branch" \
  'git --git-dir="$FIXTURE/.test-origin.git" log -1 --pretty=%B "$WORK_BRANCH" | grep -q "fix: stub fix"'

check "the report was NOT posted (stub gh pr comment was never called)" \
  '! echo "$run_log" | grep -q "stub: pr comment"'
check "the full report was written to the job summary" \
  'job_summary "$run_log" | grep -q "## Agent run report" &&
   job_summary "$run_log" | grep -q "stub agent report" &&
   job_summary "$run_log" | grep -q "second line"'

check "the full report is exposed as the action's report step output" \
  'echo "$run_log" | grep -q "report output: stub agent report" &&
   echo "$run_log" | grep -q "report output: second line"'

finish
