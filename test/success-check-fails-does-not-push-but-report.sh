#!/usr/bin/env bash
# Verifies that when success-check still fails after the agent's changes,
# the action does NOT commit or push them, but still writes the report to
# the job summary and posts it on the branch's PR.
# Complements success-check-passes-pushes-and-report.sh. Uses a stub agent
# that edits a tracked file, a success-check that always fails, and a real
# local bare repo as `origin`, so we can positively confirm nothing was
# pushed, not just that the step didn't error.
#
# Usage: bash test/success-check-fails-does-not-push-but-report.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/.lib.sh"

setup_fixture success-check-fails-branch
write_workflow test-success-check-fails <<'EOF'
success-check: "false"
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
check "success check step runs and fails" \
  'echo "$run_log" | grep -q "❌  Failure - Main Stop if success check still fails"'
check "commit and push step is skipped, not merely failed (never even attempted)" \
  '! echo "$run_log" | grep -q "⭐ Run Main Commit and push changes, if any"'
check "report step still runs (despite the earlier failure) and succeeds" \
  'echo "$run_log" | grep -q "✅  Success - Main $REPORT_STEP"'

check "no new commit landed in the local working repo (still just the fixture commit)" \
  '[ "$(git -C "$FIXTURE" log --oneline | wc -l)" -eq 1 ]'
check "nothing was pushed to origin (no branch was ever created there)" \
  '[ -z "$(git --git-dir="$FIXTURE/.test-origin.git" branch --list "$WORK_BRANCH")" ]'
check "the report was posted anyway (stub gh pr comment was called on the branch's PR)" \
  'echo "$run_log" | grep -q "stub: pr comment on #42 suppressed"'

check "the full report was written to the job summary anyway" \
  'job_summary "$run_log" | grep -q "## Agent run report" &&
   job_summary "$run_log" | grep -q "stub agent report" &&
   job_summary "$run_log" | grep -q "second line"'

check "the full report is exposed as the action's report step output anyway" \
  'echo "$run_log" | grep -q "report output: stub agent report" &&
   echo "$run_log" | grep -q "report output: second line"'

finish
