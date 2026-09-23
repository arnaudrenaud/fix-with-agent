#!/usr/bin/env bash
# Verifies run-no-more-than-once-ever-for-branch: invokes the action twice
# with the same (branch, success-check) and the guard enabled, and asserts
# that the second invocation's real steps (in particular "Run agent") never
# execute. The fixture has no `origin` remote, so nothing can be pushed.
#
# Usage: bash test/run-no-more-than-once-ever-for-branch.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/.lib.sh"

setup_fixture guard-test-branch
write_workflow test-guard <<'EOF'
success-check: "true"
run-no-more-than-once-ever-for-branch: "true"
agent-command: echo '{"result":"stub ran","total_cost_usd":0.01}'
EOF
init_fixture_repo

echo "=== Run 1 (expect: proceeds, runs the agent) ==="
run1_log="$(run_act 2>&1)" || true
echo "$run1_log" | grep -E "⭐ Run Main|proceed=|Agent cost"

echo
echo "=== Run 2, same branch + check (expect: blocked, agent never runs) ==="
run2_log="$(run_act 2>&1)" || true
echo "$run2_log" | grep -E "⭐ Run Main|proceed=|Agent cost"

echo
check "run 1 proceeds (proceed=true)" \
  'echo "$run1_log" | grep -q "proceed=true"'
check "run 1 actually runs the agent (Run agent step executes)" \
  'echo "$run1_log" | grep -q "⭐ Run Main Run agent"'
check "run 1 reports an agent cost (confirms the agent command really ran, not just the step wrapper)" \
  'echo "$run1_log" | grep -q "Agent cost (USD): 0.01"'

check "run 2 is blocked (proceed=false)" \
  'echo "$run2_log" | grep -q "proceed=false"'
check "run 2 does NOT run the agent (Run agent step is entirely absent, not merely failed)" \
  '! echo "$run2_log" | grep -q "⭐ Run Main Run agent"'
check "run 2 reports no agent cost" \
  '! echo "$run2_log" | grep -q "Agent cost"'

finish
