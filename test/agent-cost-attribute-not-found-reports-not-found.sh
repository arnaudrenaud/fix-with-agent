#!/usr/bin/env bash
# Verifies that when agent-cost-attribute is set but the agent's JSON output
# has no value for that field, the report ends with
# "`<agent-cost-attribute>`: not found in agent command output."
#
# Usage: bash test/agent-cost-attribute-not-found-reports-not-found.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/.lib.sh"

setup_fixture cost-attribute-not-found-branch
write_workflow test-cost-attribute-not-found <<'EOF'
success-check: "true"
agent-cost-attribute: cost_in_usd
agent-command: |
  printf 'stub agent report\n' > "$RUNNER_TEMP/fix-with-agent-report.md"
  echo '{"result":"stub ran","total_cost_usd":0.01}'
EOF
init_fixture_repo

EXPECTED='`cost_in_usd`: not found in agent command output.'

run_log="$(run_act 2>&1)" || true
echo "$run_log" | grep -E "⭐ Run Main|✅|❌"

echo
check "report step runs and succeeds" \
  'echo "$run_log" | grep -q "✅  Success - Main $REPORT_STEP"'
check "the job summary holds the agent report" \
  'job_summary "$run_log" | grep -q "stub agent report"'
check "the job summary reports the cost as not found" \
  'job_summary "$run_log" | grep -qF -- "$EXPECTED"'
check "the job summary does not report the value of another field" \
  '! job_summary "$run_log" | grep -qF "0.01"'
check "the \`report\` output reports the cost as not found" \
  'echo "$run_log" | grep -qF -- "report output: $EXPECTED"'

finish
