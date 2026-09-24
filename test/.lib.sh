# Shared helpers for the act-based tests in this directory. Source it from a
# test script (it is a dotfile so .run-tests.sh does not pick it up as a test).
#
# Each test exercises the action under real GitHub Actions composite-action
# semantics, using nektos/act (https://github.com/nektos/act) instead of a
# hand-rolled reimplementation of GitHub's expression evaluator. It builds a
# throwaway, disposable fixture repo containing a copy of the current
# action.yml and a tiny workflow that invokes it, runs act against that
# fixture with --bind (safe here since the fixture is disposable — never do
# this against a real checkout), then asserts on act's log output and the
# resulting git state.
#
# Requires: act, docker (with the daemon running).

ACTION_YML="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/action.yml"

if ! command -v act >/dev/null 2>&1; then
  echo "act is not installed (https://github.com/nektos/act) — e.g. \`brew install act\`" >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "docker is not running — act needs a running Docker daemon" >&2
  exit 1
fi

# On Linux, act's containers run as root and write root-owned files into the
# bind-mounted fixture, so fall back to sudo; never let cleanup change the
# test's own exit status.
cleanup() {
  local status=$?
  rm -rf "$FIXTURE" 2>/dev/null || sudo -n rm -rf "$FIXTURE" 2>/dev/null ||
    echo "warning: could not remove $FIXTURE" >&2
  exit "$status"
}

# Usage: setup_fixture <branch-prefix>
# Creates $FIXTURE (removed on exit) holding a copy of action.yml, and picks
# a unique $WORK_BRANCH. act's local cache emulation is a persistent
# host-level store, shared across fixtures and runs (not scoped to the
# fixture directory), so a unique branch per run keeps cache keys
# collision-free and the test deterministic regardless of earlier runs.
setup_fixture() {
  FIXTURE="$(mktemp -d)"
  trap cleanup EXIT
  WORK_BRANCH="$1-$(date +%s)-$$"
  mkdir -p "$FIXTURE/.github/actions/fix-with-agent" "$FIXTURE/.github/workflows"
  cp "$ACTION_YML" "$FIXTURE/.github/actions/fix-with-agent/action.yml"
}

# Usage: write_workflow <workflow-name> <<EOF
#   <extra action inputs, unindented>
# EOF
# Writes a workflow that installs a stub gh (no real GitHub API calls),
# invokes the action with common dummy inputs plus the extra ones on stdin,
# then (step "Print report output", run even if the action failed) prints the
# action's `report` output, each line as "report output: …".
# The stub reports the branch as having open PR #$STUB_PR_NUMBER (42 if
# unset); set STUB_PR_NUMBER="" to simulate a branch with no PR.
write_workflow() {
  {
    cat <<EOF
name: $1
on: workflow_dispatch
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Install stub gh (no real GitHub API calls in this test)
        run: |
          cat > /usr/local/bin/gh <<'STUB'
          #!/usr/bin/env bash
          if [ "\$1" = "run" ] && [ "\$2" = "view" ]; then
            echo "stub failed workflow logs"
            exit 0
          fi
          if [ "\$1" = "pr" ] && [ "\$2" = "list" ]; then
            echo "${STUB_PR_NUMBER-42}"
            exit 0
          fi
          if [ "\$1" = "pr" ] && [ "\$2" = "comment" ]; then
            echo "stub: pr comment on #\$3 suppressed"
            exit 0
          fi
          echo "stub gh: unhandled: \$*" >&2
          exit 1
          STUB
          chmod +x /usr/local/bin/gh

      - name: Invoke the action
        id: fix
        uses: ./.github/actions/fix-with-agent
        with:
          failed-workflow-run-id: "1"
          branch: "$WORK_BRANCH"
          github-token: "dummy"
          agent-install-command: "true"
          agent-env: ""
EOF
    sed 's/^/          /'
    cat <<'EOF'

      - name: Print report output
        if: always()
        env:
          REPORT: ${{ steps.fix.outputs.report }}
        run: |
          printf '%s\n' "$REPORT" | sed 's/^/report output: /'
EOF
  } > "$FIXTURE/.github/workflows/test.yml"
}

# Usage: init_fixture_repo [--with-origin]
# Commits the fixture (plus a tracked file.txt the stub agent can edit) and
# cds into it. --with-origin adds a real local bare repo as `origin`, so a
# push (or its absence) can be positively verified without reaching any real
# remote; it lives inside the fixture and is referenced by a relative path,
# so it resolves regardless of where --bind remaps the workspace inside the
# container. Without it there is no `origin`, so nothing can be pushed.
init_fixture_repo() {
  cd "$FIXTURE"
  git init -q .
  if [ "${1:-}" = "--with-origin" ]; then
    git init -q --bare .test-origin.git
    echo ".test-origin.git/" > .gitignore
    git remote add origin ./.test-origin.git
  fi
  echo "orig" > file.txt
  git add -A
  git -c user.email=test@test.com -c user.name=test commit -q -m fixture
}

# Name of the action's report step, as it appears in act's log.
REPORT_STEP="Whatever the outcome, write report to job summary and pull request comment, if any"

run_act() {
  act workflow_dispatch -P ubuntu-latest=catthehacker/ubuntu:act-latest --pull=false --bind
}

# Usage: job_summary <act log>
# Prints what the run wrote to $GITHUB_STEP_SUMMARY: act echoes it in its log
# as "⚙  Summary - <first line>", followed by the remaining lines as-is.
job_summary() {
  awk '/⚙  Summary - /{ sub(/.*⚙  Summary - /, ""); on = 1 } /^\[/{ on = 0 } on' <<<"$1"
}

failed=0

# Usage: check <description> <shell condition, eval'd>
check() {
  local desc="$1" cond="$2"
  if eval "$cond"; then
    echo "ok - $desc"
  else
    echo "not ok - $desc"
    failed=1
  fi
}

# Prints PASS, or prints FAIL and exits non-zero if any check failed.
finish() {
  echo
  if [ "$failed" -eq 0 ]; then
    echo "PASS"
  else
    echo "FAIL"
    exit 1
  fi
}
