#!/usr/bin/env bash
# Verifies the *default* behavior (run-no-more-than-once-ever-for-branch not
# passed at all, so it falls back to its "false" default). Complements
# run-no-more-than-once-ever-for-branch.sh: that one proves the guard blocks
# a second run when opted in; this one proves nothing blocks it when the
# input is simply omitted, i.e. the guard is genuinely opt-in, not opt-out.
# Invokes the action twice with the same (branch, success-check) and asserts
# that the second invocation's real steps (in particular "Run agent") execute
# just like the first. The fixture has no `origin` remote, so nothing can be
# pushed.
#
# Usage: bash test/run-twice-for-branch.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/.lib.sh"

setup_fixture no-guard-test-branch
write_workflow test-no-guard <<'EOF'
success-check: "true"
agent-command: echo '{"result":"stub ran","total_cost_usd":0.01}'
EOF
init_fixture_repo

echo "=== Run 1 (expect: proceeds, runs the agent) ==="
run1_log="$(run_act 2>&1)" || true
echo "$run1_log" | grep -E "⭐ Run Main|proceed=|Agent cost"

echo
echo "=== Run 2, same branch + check, guard input omitted (expect: proceeds again, runs the agent again) ==="
run2_log="$(run_act 2>&1)" || true
echo "$run2_log" | grep -E "⭐ Run Main|proceed=|Agent cost"

echo
check "run 1 proceeds (proceed=true)" \
  'echo "$run1_log" | grep -q "proceed=true"'
check "run 1 actually runs the agent (Run agent step executes)" \
  'echo "$run1_log" | grep -q "⭐ Run Main Run agent"'
check "run 1 reports an agent cost (confirms the agent command really ran, not just the step wrapper)" \
  'echo "$run1_log" | grep -q "Agent cost (USD): 0.01"'

check "run 2 also proceeds (proceed=true) — omitting the guard input is not the same as enabling it" \
  'echo "$run2_log" | grep -q "proceed=true"'
check "run 2 also runs the agent (Run agent step executes again)" \
  'echo "$run2_log" | grep -q "⭐ Run Main Run agent"'
check "run 2 also reports an agent cost" \
  'echo "$run2_log" | grep -q "Agent cost (USD): 0.01"'
check "run 2 does not print the guard-blocked notice" \
  '! echo "$run2_log" | grep -q "Explain why nothing happened"'

finish
