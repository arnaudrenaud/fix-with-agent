## Usage

For example, to fix failures in a workflow named "Build and test" when triggered by Renovate pull requests:

```yml
name: "Fix breaking changes in Renovate PRs"

on:
  workflow_run:
    workflows:
      - "Build and test" # TODO: Replace by the `name` of the workflow whose failure should trigger the action
    types:
      - completed
    branches:
      - "renovate/**" # TODO: Replace by the name pattern of the branches you want to monitor

concurrency:
  group: fix-tests-${{ github.event.workflow_run.head_branch }}
  cancel-in-progress: true

permissions:
  contents: write
  pull-requests: write
  actions: read

jobs:
  fix-tests:
    name: Fix tests
    if: github.event.workflow_run.conclusion == 'failure'
    runs-on: ubuntu-latest

    steps:
      - name: Generate GitHub App token to re-trigger test run after fix is pushed
        # A push made with the default `GITHUB_TOKEN` would not trigger any CI check
        id: app-token
        uses: actions/create-github-app-token@v3
        with:
          client-id: ${{ secrets.AUTO_FIX_APP_CLIENT_ID }}
          private-key: ${{ secrets.AUTO_FIX_APP_PRIVATE_KEY }}

      - name: Checkout branch
        uses: actions/checkout@v5
        with:
          ref: ${{ github.event.workflow_run.head_branch }}
          fetch-depth: 0
          token: ${{ steps.app-token.outputs.token }}

      - name: Setup Node
        uses: actions/setup-node@v5
        with:
          node-version: "22"

      - name: Install dependencies
        run: npm ci --ignore-scripts # Prevent a malicious update from, e.g., reading your secrets

      - name: Fix tests
        uses: arnaudrenaud/fix-with-agent@v1
        with:
          success-check: npm run build && npm run test # TODO: Replace by your own success check
          failed-workflow-run-id: ${{ github.event.workflow_run.id }}
          branch: ${{ github.event.workflow_run.head_branch }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          task-description: >-
            Fix the failed test run, probably following a breaking change in a dependency upgrade in latest commit.
            If applicable, mention URLs of documentation and discussions that support the chosen fix.
            Do not delete or disable tests unless a test is obsolete because of this change, and explain why.
          commit-title: "fix(auto): Auto-fix tests following breaking change in dependency"
          # TODO: Replace the following args by your own agent setup if you don't use `claude`
          agent-install-command: npm install -g @anthropic-ai/claude-code
          agent-env: |
            CLAUDE_CODE_OAUTH_TOKEN=${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          agent-command:
            | # Agent command must be non-interactive and take stdin for its query
            claude \
              -p \
              --permission-mode bypassPermissions \
              --max-budget-usd 2.00 \
              --output-format json
          agent-cost-attribute: total_cost_usd # Optional arg: in the agent's JSON output, attribute `total_cost_usd` will be read to report cost
          agent-timeout-minutes: 10
```

## Development

Run tests:

```sh
./test/.run-tests.sh
```
