#!/usr/bin/env bash
# Verifies that when agent-cost-attribute is set and the agent's JSON output
# has a value for that field, the report ends with
# "`<agent-cost-attribute>`: <value>.", after the agent's own report.
#
# Usage: bash test/agent-cost-attribute/found-reports-value.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../.lib.sh"

setup_fixture cost-attribute-found-branch
write_workflow test-cost-attribute-found <<'EOF'
success-check: "true"
agent-cost-attribute: cost_in_usd
agent-command: |
  printf 'stub agent report\n' > "$RUNNER_TEMP/fix-with-agent-report.md"
  echo '{"result":"stub ran","cost_in_usd":0.42}'
EOF
init_fixture_repo

EXPECTED='`cost_in_usd`: 0.42.'

run_log="$(run_act 2>&1)" || true
echo "$run_log" | grep -E "⭐ Run Main|✅|❌"

echo
check "report step runs and succeeds" \
  'echo "$run_log" | grep -q "✅  Success - Main $REPORT_STEP"'
check "the job summary reports the cost value" \
  'job_summary "$run_log" | grep -qF -- "$EXPECTED"'
check "in the job summary, the cost comes after the agent report" \
  'job_summary "$run_log" | grep -A10 "stub agent report" | grep -qF -- "$EXPECTED"'
check "the \`report\` output reports the cost value" \
  'echo "$run_log" | grep -qF -- "report output: $EXPECTED"'

finish
