#!/usr/bin/env bash
# Verifies that when agent-cost-attribute is not passed, the report makes no
# mention of the agent cost, even though the agent's JSON output has a cost
# field.
#
# Usage: bash test/agent-cost-attribute-not-set-reports-no-cost.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/.lib.sh"

setup_fixture cost-attribute-not-set-branch
write_workflow test-cost-attribute-not-set <<'EOF'
success-check: "true"
agent-command: |
  printf 'stub agent report\n' > "$RUNNER_TEMP/fix-with-agent-report.md"
  echo '{"result":"stub ran","total_cost_usd":0.01}'
EOF
init_fixture_repo

run_log="$(run_act 2>&1)" || true
echo "$run_log" | grep -E "⭐ Run Main|✅|❌"

echo
check "report step runs and succeeds" \
  'echo "$run_log" | grep -q "✅  Success - Main $REPORT_STEP"'
check "the job summary holds the agent report" \
  'job_summary "$run_log" | grep -q "stub agent report"'
check "the job summary does not mention cost" \
  '! job_summary "$run_log" | grep -qiE "cost|0\.01"'
check "the \`report\` output holds the agent report" \
  'echo "$run_log" | grep -q "report output: stub agent report"'
check "the \`report\` output does not mention cost" \
  '! echo "$run_log" | sed -n "s/.*report output: //p" | grep -qiE "cost|0\.01"'

finish
