---
name: demo-plan
description: Build a step-by-step demo plan from Azure DevOps tickets assigned to the user in specified board columns. Fetches ticket details, groups related items, and produces a demoable walkthrough.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Agent, Write
argument-hint: "[column1, column2, ...]"
context: inherit
---

# Demo Plan Generator

You help the user prepare for sprint demos by fetching their Azure DevOps tickets, analyzing them, and producing a structured demo plan.

## Step 1: Parse Arguments

Extract board column names from `$ARGUMENTS`.

- If arguments are provided, treat them as comma-separated board column names (e.g., "In UAT, Dev Complete").
- If no arguments are provided, default to: `In UAT, Dev Complete`.

## Step 2: Detect ADO Org and Project

Run these in parallel:

1. `az devops configure --list` — check for a configured default org/project
2. `git remote get-url origin` — parse org and project from the remote URL

Supported remote formats:
- SSH: `git@ssh.dev.azure.com:v3/{org}/{project}/{repo}`
- HTTPS: `https://dev.azure.com/{org}/{project}/_git/{repo}`
- HTTPS legacy: `https://{org}@dev.azure.com/{org}/{project}/_git/{repo}`

URL-decode the project name (e.g., `MAU%20DEX` → `MAU DEX`).

If neither source yields an org, ask the user for their Azure DevOps org URL.

## Step 3: Query Tickets

Get the current user:
```bash
az account show --query user.name -o tsv
```

Query tickets assigned to the user in the specified board columns using `System.BoardColumn`:
```bash
az boards query --wiql "SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State], [System.BoardColumn] FROM workitems WHERE [System.AssignedTo] = @Me AND ([System.BoardColumn] = 'Column1' OR [System.BoardColumn] = 'Column2') ORDER BY [System.BoardColumn]" --org https://dev.azure.com/{org} --project "{project}" -o json
```

Build the `WHERE` clause dynamically from the parsed column names.

If no tickets are found, inform the user and stop.

## Step 4: Fetch Ticket Details

For each ticket found, fetch full details **in parallel** using subagents (Agent tool). For each ticket:

1. Fetch the work item:
   ```bash
   az boards work-item show --id {id} --org https://dev.azure.com/{org}
   ```

2. Fetch comments:
   ```bash
   az devops invoke --area wit --resource comments --route-parameters project="{project}" workItemId={id} --org https://dev.azure.com/{org} --api-version "7.1-preview"
   ```

3. Traverse the parent chain: Check relations for `System.LinkTypes.Hierarchy-Reverse`, fetch parent, repeat until no more parents.

4. Check for screenshots in the description HTML (`<img src="...">` tags). Download and view them:
   ```bash
   TOKEN=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
   curl -s -L "{image_url}" -H "Authorization: Bearer $TOKEN" -o /tmp/ticket-{id}-image-{n}.png
   ```

For each ticket, collect:
- Title, type, state, board column
- Description and acceptance criteria
- Comments (author, date, content) — especially QA/tester feedback
- Parent chain context (title, type, state, one-sentence summary per ancestor)
- Linked PRs and branches

## Step 5: Analyze and Group Tickets

After all ticket details are collected, analyze them for grouping:

### Grouping Rules

Tickets should be **demoed together** if any of the following apply:
- They share a **common parent** (Feature or Epic)
- One ticket is a **predecessor/successor** of another (check relations for `System.LinkTypes.Dependency-Forward` and `System.LinkTypes.Dependency-Reverse`)
- They affect the **same functional area** (e.g., same UI screen, same import flow, same API domain)

### Demoability Assessment

For each ticket, determine if it is demoable:
- **Demoable**: Has UI changes, API behavior changes, or user-facing functionality that can be shown
- **Walkthrough only**: Infrastructure, DevOps, pipeline, SSL/domain, or configuration-only changes — explain what to show in a portal/tool walkthrough
- **Not demoable**: Pure backend refactoring, spike/research items, or environment setup with nothing visible to show — explain why

### Known Issues

Flag any **UAT tester feedback** from comments that reports bugs or issues. These should be called out as "Known UAT Issues to Verify" so the user can confirm they're resolved before the demo.

## Step 6: Build the Demo Plan

Produce a structured markdown demo plan with the following format:

### For each group:

```markdown
## Group N: {Group Name} (Demo Together / Standalone)

**Tickets:** #{id1} + #{id2} — {brief description}

{One sentence on why these are grouped, or note if standalone}

### #{id} — {Title}

1. Step-by-step demo instructions
2. What to click / navigate to
3. What to verify / show

### Known UAT Issues to Verify

- {Issue from comments, if any}
```

### At the end, include a summary table:

```markdown
## Recommended Demo Order

| Order | Ticket(s) | Type | Group With |
|-------|-----------|------|------------|
| 1 | #X, #Y | Description | Together |
| 2 | #Z | Description | Standalone |
```

Order the groups so that the **most visually impressive / feature-rich demos go first**, and infrastructure/walkthrough-only items go last.

## Step 7: Write the Plan

Write the demo plan to a file called `demo-plan.md` in the current working directory. Inform the user of the file path when done.

If a `demo-plan.md` already exists, ask the user if they want to overwrite it or use a different filename.
