---
name: pr
description: Create a pull request or retrieve PR feedback/build status. Supports both GitHub (gh) and Azure DevOps (az repos).
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Agent
argument-hint: "[--draft] or [PR_ID]"
context: inherit
---

Create a pull request for the current branch using the appropriate CLI based on the git remote origin. If `--draft` is passed as an argument, create the PR as a draft. If a numeric PR ID is passed as an argument (e.g. `/pr 2221`), retrieve and display the review feedback and build status for that PR instead.

---

## PR Feedback Mode (when a numeric ID is the argument)

If the argument is a number, run the feedback retrieval flow below. Skip the create flow entirely.

### F1 — Parse remote details

Run `git remote get-url origin` and extract ORG, PROJECT, REPO using the same rules as Step 2 below.

### F2 — Fetch PR threads

**GitHub:**
```
gh api repos/ORG/REPO/pulls/PR_ID/comments \
  --jq '.[] | "--- Comment \(.id) by \(.user.login) ---\n\(.body)\n"'
```

Also fetch general PR review comments (not line-level):
```
gh api repos/ORG/REPO/pulls/PR_ID/reviews \
  --jq '.[] | select(.body != "") | "--- Review by \(.user.login) [\(.state)] ---\n\(.body)\n"'
```

**Azure DevOps** — the `az repos pr` CLI has no thread command; use the REST API directly:
```
TOKEN=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://dev.azure.com/ORG/PROJECT/_apis/git/repositories/REPO/pullRequests/PR_ID/threads?api-version=7.1"
```
Then parse the JSON response and print only non-system comments:
```python
import sys, json
data = json.load(sys.stdin)
for t in data.get('value', []):
    status = t.get('status', '')
    for c in t.get('comments', []):
        if c.get('commentType') == 'system':
            continue
        content = c.get('content', '').strip()
        if not content:
            continue
        author = c.get('author', {}).get('displayName', '')
        print(f"--- Thread {t['id']}, Comment {c['id']} [{status}] ({author}) ---")
        print(content)
        print()
```

### F2b — Check build status

**GitHub:**
```
gh api repos/ORG/REPO/pulls/PR_ID --jq '.head.sha'
```
Then fetch check runs for that SHA:
```
gh api repos/ORG/REPO/commits/SHA/check-runs \
  --jq '.check_runs[] | select(.conclusion == "failure") | "--- \(.name) [FAILED] ---\n\(.output.summary // "No summary")\n"'
```
If no failed checks, report all checks passed. If there are failures, display the check name, conclusion, and output summary.

**Azure DevOps:**

> **Important:** The ADO REST API endpoints for build timeline (`/timeline`) and logs (`/logs`) frequently return empty 200 responses. Always prefer the `az` CLI commands below, which reliably return data.

1. Find the most recent builds for this PR:
   ```
   az pipelines build list \
     --org "https://dev.azure.com/ORG" \
     --project "PROJECT" \
     --reason pullRequest \
     --top 5 \
     --query "sort_by([?contains(sourceBranch, 'PR_ID')], &finishTime) | reverse(@)" \
     -o json
   ```
   Match builds whose `sourceBranch` contains the PR number (e.g. `refs/pull/PR_ID/merge`). Take the most recent one.

2. For each failed build, fetch full details including validation results:
   ```
   az pipelines build show \
     --id BUILD_ID \
     --org "https://dev.azure.com/ORG" \
     --project "PROJECT" \
     -o json
   ```
   Check these fields in order:
   - **`validationResults`** — pipeline YAML validation errors (e.g. missing environments, invalid references). This is the most common cause of immediate build failures. Display each entry's `result` and `message`.
   - If `validationResults` is empty, try the build timeline via CLI:
     ```
     az devops invoke \
       --area build \
       --resource timeline \
       --route-parameters project="PROJECT" buildId=BUILD_ID \
       --api-version 7.1 \
       --org "https://dev.azure.com/ORG" \
       --http-method GET \
       -o json
     ```
     Look for records where `result == "failed"` and display their `name`, `type`, and any `issues` with `type == "error"`.
   - If the timeline is also empty, fall back to fetching build logs:
     ```
     az pipelines runs artifact list \
       --run-id BUILD_ID \
       --org "https://dev.azure.com/ORG" \
       --project "PROJECT" \
       -o json
     ```
     Or direct the user to the build URL for manual inspection.

3. Display a summary: build number, result, and the specific errors found.

### F3 — Display results

Group output into two sections:

**Build Status:** Show the most recent build result. If failed, display the specific errors (validation results, failed task names + error messages). Include the build URL for reference.

**Review Feedback:** Group PR thread comments by thread. Show the thread status (`active`, `fixed`, `closed`, `wontFix`) alongside each comment so it is clear which items still need attention.

---

## Create Mode (default — no PR ID argument)

## Step 1 — Gather git context (run these in parallel)

- `git remote get-url origin` — to determine which CLI to use and parse connection details
- `git branch --show-current` — current branch name
- `git status -sb` — check if the branch has an upstream and if there are uncommitted changes

## Step 2 — Determine CLI and parse remote details

Inspect the origin URL:

**GitHub** — URL contains `github.com`:
- SSH: `git@github.com:ORG/REPO.git`
- HTTPS: `https://github.com/ORG/REPO.git`
- CLI: `gh`

**Azure DevOps** — URL contains `dev.azure.com` or `visualstudio.com`:
- SSH: `git@ssh.dev.azure.com:v3/ORG/PROJECT/REPO`
- HTTPS: `https://ORG@dev.azure.com/ORG/PROJECT/_git/REPO`
- CLI: `az repos`
- Org URL: `https://dev.azure.com/ORG`
- Note: URL-decode percent-encoded characters in PROJECT and REPO (e.g. `%20` → space)

## Step 3 — Detect the target (base) branch

Try each of the following in order, stopping at the first success:

1. **Query the remote's configured default branch:**
   - GitHub: `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`
   - Azure DevOps: `az repos show --org "https://dev.azure.com/ORG" --project "PROJECT" --repository "REPO" --query defaultBranch --output tsv` — then strip the `refs/heads/` prefix

2. **Local tracking reference:** `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'`

3. **Heuristic:** check which of `develop`, `main`, `master` exists on the remote (`git ls-remote --heads origin develop main master`) and pick the first one found in that order.

## Step 4 — Verify there are commits to PR

Run `git log <base>...HEAD --oneline`. If there are no commits, stop and tell the user there is nothing to open a PR for.

## Step 5 — Push if needed

Check the `git status -sb` output from Step 1. If the branch has no upstream tracking branch, push it: `git push -u origin <current-branch>`.

## Step 6 — Collect change information (run in parallel)

- `git log <base>...HEAD --oneline` — list of commits unique to this branch
- `git diff <base>...HEAD --stat` — files changed

## Step 7 — Draft the PR title and description

**Title:** Derive from the commits (typically the most recent non-merge commit message). Keep it under 70 characters.

**Description:** A `## Summary` section only — a concise bullet-point list describing what changed and why. No test plan section. Do not include any Claude attribution, co-author lines, or "Generated with Claude Code" footers. Use a HEREDOC when passing to the CLI to avoid shell escaping issues.

## Step 8 — Prompt for reviewers

Ask the user: "Who should be added as reviewers? (Enter names, emails, or 'none'). Prefix with 'required:' to mark as required (e.g. 'required: Jane Doe')"

If the user says 'none' or skips, proceed to Step 9 with no reviewers.

Otherwise, for each name or partial name provided, search the org to resolve the identity. Track whether each reviewer was marked as required.

**GitHub:**
```
gh api /orgs/ORG/members --jq '.[] | select(.login | test("SEARCH"; "i")) | {login, name: .name}'
```
If the org search yields no results, fall back to:
```
gh api /search/users?q=SEARCH+org:ORG --jq '.items[] | {login, name: .name}'
```

**Azure DevOps:**
```
az devops user list --org "https://dev.azure.com/ORG" --query "items[?contains(user.displayName, 'SEARCH') || contains(user.mailAddress, 'SEARCH')].[user.displayName, user.mailAddress]" --output table
```

If multiple matches are found, show them to the user and ask which one to add. If no matches are found, tell the user and ask if they want to try a different search term or skip that reviewer.

Collect the resolved identities (GitHub: login handles; Azure DevOps: email addresses and user IDs) for all confirmed reviewers, noting which are required.

## Step 9 — Create the PR

**GitHub:**
```
gh pr create \
  --title "TITLE" \
  --body "$(cat <<'EOF'
DESCRIPTION
EOF
)" \
  --base BASE_BRANCH \
  [--draft] \
  [--reviewer login1 --reviewer login2 ...]
```

**Azure DevOps:**
```
az repos pr create \
  --org "https://dev.azure.com/ORG" \
  --project "PROJECT" \
  --repository "REPO" \
  --source-branch "CURRENT_BRANCH" \
  --target-branch "BASE_BRANCH" \
  --title "TITLE" \
  --description "$(cat <<'EOF'
DESCRIPTION
EOF
)" \
  [--draft true] \
  [--reviewers "email1@org.com" "email2@org.com"]
```

## Step 10 — Set required reviewers (Azure DevOps only)

The `az repos pr create --reviewers` flag and `az repos pr reviewer add` do NOT support marking reviewers as required. For any reviewer marked as required in Step 8, use the REST API to set `isRequired: true`:

1. Get the PR ID from the Step 9 output.
2. Get the reviewer's ID. If not already known, list the PR reviewers:
   ```
   az repos pr reviewer list --id PR_ID --org "https://dev.azure.com/ORG" -o json
   ```
   Match the reviewer by `displayName` or `uniqueName` to get their `id`.
3. Set `isRequired` via the REST API:
   ```
   az devops invoke \
     --area git \
     --resource pullRequestReviewers \
     --route-parameters project="PROJECT" repositoryId=REPO_ID pullRequestId=PR_ID reviewerId=REVIEWER_ID \
     --http-method PUT \
     --in-file /dev/stdin \
     -o json <<< '{"isRequired": true}'
   ```
   The `repositoryId` and `pullRequestId` can be extracted from the Step 9 JSON output.

## Step 11 — Link the work item to the PR

**Only applies when the remote is Azure DevOps.**

Detect the ticket number from the current branch name (same logic as Step 12). If a number is found, link it to the newly created PR automatically — no need to ask the user:

```
az repos pr work-item add \
  --id PR_ID \
  --work-items TICKET \
  --org "https://dev.azure.com/ORG"
```

If the command succeeds, note to the user that work item #{ticket} has been linked. If it fails, report the error but continue.

## Step 12 — Return the PR URL

Extract and display the PR URL from the CLI output so the user can navigate to it directly.

## Step 13 — Offer to move the ticket on the board

**Only applies when the remote is Azure DevOps.**

1. **Detect the ticket number** from the current branch name. Look for a numeric sequence in the branch name (e.g. `fix/5275-description` → `5275`, `feature/1234-some-feature` → `1234`). If no number is found, skip this step.

2. **Ask the user**: "Would you like to move ticket #{ticket} on the board?"

3. If yes, **resolve the first team and its Backlog items board**. Run these in parallel:

   **List teams:**
   ```
   az devops team list --org "https://dev.azure.com/{org}" --project "{project}" --query "[0].id" --output tsv
   ```

   **Fetch the work item** to capture the Kanban column field name (needed for the update):
   ```
   az boards work-item show --id {ticket} --org "https://dev.azure.com/{org}"
   ```
   From the work item fields, find the key matching `WEF_*_Kanban.Column` — this is the field to update.

   Then, using the first team's ID, **get the board ID** for the "Backlog items" board:
   ```
   az devops invoke \
     --area work \
     --resource boards \
     --route-parameters project="{project}" team="{teamId}" \
     --org "https://dev.azure.com/{org}"
   ```
   Pick the board whose `name` is "Backlog items".

   Then **fetch the columns** via the REST API (the `az devops invoke --resource columns` route is not supported):
   ```
   TOKEN=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
   curl -s -H "Authorization: Bearer $TOKEN" \
     "https://dev.azure.com/{org}/{project}/{teamId}/_apis/work/boards/{boardId}/columns?api-version=7.1"
   ```
   Extract the column names from the `value` array.

4. **Check for a PR column**: Look through the returned column names for one that contains "PR", "Pull Request", or "Code Review" (case-insensitive).
   - If a match is found, ask the user: "Move to '{column name}'?" and proceed if confirmed.
   - If no match is found, display all available column names and ask the user which column to move the ticket to.

5. **Update the work item's board column** using the `WEF_*_Kanban.Column` field captured in step 3 (`System.BoardColumn` is read-only and cannot be set directly):
   ```
   az boards work-item update \
     --id {ticket} \
     --org "https://dev.azure.com/{org}" \
     --fields "{wef_kanban_column_field}={selected column name}"
   ```

6. Confirm the move to the user.
