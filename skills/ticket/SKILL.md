---
name: ticket
description: Fetch and summarize an Azure DevOps work item with full parent chain, comments, and screenshots. Can also explain or implement the fix.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Agent
argument-hint: "<ticket-number> [person-name | explain | fix]"
context: inherit
---

You are helping the user work with an Azure DevOps work item. The user invoked this with: $ARGUMENTS

## Step 1: Parse Arguments

Extract from `$ARGUMENTS`:
- **Ticket number** (required): a numeric work item ID
- **Extra context** (optional): anything after the number — e.g. a person's name, "explain", "fix", "complete", or a specific question

## Step 2: Detect the ADO Org and Project

Run these in parallel:
1. `az devops configure --list` — check for a configured default org
2. `git remote get-url origin` — parse the org and project from the remote URL

Supported remote formats:
- SSH: `git@ssh.dev.azure.com:v3/{org}/{project}/{repo}` → org = segment 1, project = segment 2
- HTTPS: `https://dev.azure.com/{org}/{project}/_git/{repo}` → org = segment 1, project = segment 2
- HTTPS legacy: `https://{org}@dev.azure.com/{org}/{project}/_git/{repo}` → org = segment 1 after @, project = segment 2

URL-decode the project name (e.g. `MAU%20DEX` → `MAU DEX`).

If neither source yields an org, ask the user for their Azure DevOps org URL before proceeding.

## Step 3: Fetch the Work Item and Comments

Run both in parallel:

**Work item:**
```
az boards work-item show --id {ticket} --org https://dev.azure.com/{org}
```

**Comments:**
```
az devops invoke \
  --area wit \
  --resource comments \
  --route-parameters project="{project}" workItemId={ticket} \
  --org https://dev.azure.com/{org} \
  --api-version "7.1-preview"
```

Always retrieve both the work item details AND the comments — comments frequently contain tester feedback, bug reports, reproduction steps, and clarifications that are essential for understanding and completing the work.

**Screenshots:** ADO screenshots are embedded directly in the `System.Description` HTML as `<img src="...">` tags. After fetching the work item, scan the description for any `<img>` tags and extract their `src` URLs. For each image URL found, download it and view it using the Read tool:

```
TOKEN=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
curl -s -L "{image_url}" -H "Authorization: Bearer $TOKEN" -o /tmp/ticket-{ticket}-image-{n}.png
```

Then read each downloaded file with the Read tool. Screenshots often contain critical visual context — UI bugs, error messages, expected vs. actual behavior — that cannot be inferred from text alone. Always view every screenshot before summarizing or implementing.

## Step 3b: Traverse Parent Tickets

After fetching the work item in Step 3, inspect its `relations` array for a relation with `rel === "System.LinkTypes.Hierarchy-Reverse"` — this is the parent link. The parent work item ID is the last path segment of the relation's `url` field.

If a parent exists, fetch it and its comments in parallel (same commands as Step 3, substituting the parent ID). Also scan the parent's description for screenshots and download any images found, using the same token-based curl approach with filenames like `/tmp/ticket-{parentId}-image-{n}.png`.

Then inspect the parent's own relations for another `System.LinkTypes.Hierarchy-Reverse` link, and repeat — continuing up the chain until a work item has no parent relation. There is no depth limit; traverse all the way to the root.

Collect the full ancestry chain: `[root, ..., grandparent, parent, ticket]`.

Run each level's work-item fetch and comments fetch in parallel with each other where possible, but each level must resolve before you can determine the next level's ID.

## Step 4: Summarize the Ticket

Begin with the **ancestry chain** (if any parents were found), presented from root down to the target ticket. For each ancestor show only: title, type, state, and a one-sentence description summary. This gives the reader the "why" behind the ticket.

Then present the full detail for the **target ticket**:
- **Title** and **type** (Bug, PBI, Task, etc.)
- **State** and **assigned to**
- **Description** and **acceptance criteria**
- **Testing/scope notes** (if present)
- **Comments** — include author, date, and full content for each; pay special attention to any comments from QA/testers reporting failures or unexpected behavior
- **Screenshots** — describe what each screenshot shows and how it relates to the ticket (e.g. the reported bug, expected behavior, UI context)

If any parent ticket contains information that adds meaningful context to the target ticket (e.g. an overarching goal, a design decision, related acceptance criteria), call it out explicitly under a **"Parent Context"** heading rather than burying it in the ancestry chain.

## Step 5: Determine Mode

**If extra context was provided**, use it to determine intent:
- A person's name → focus on that person's comments and explain what they're reporting
- Words like "explain", "what's happening", "why" → explain the issue by tracing it through the codebase
- Words like "fix", "implement", "complete", "do it", "work on it" → implement the solution

**If only a ticket number was given**, ask the user:
> "Would you like me to explain the issue/requirements, or should I implement the fix?"

## Step 6: Implementing a Fix

If the user wants you to implement:

1. Read all relevant files before touching anything — never modify code you haven't read
2. Understand existing patterns in the codebase before writing new code
3. Make only the changes necessary to satisfy the acceptance criteria
4. Do not refactor surrounding code, add comments, or over-engineer
5. When done, summarize what was changed and why

## Step 7: Explaining an Issue

If the user wants an explanation:

1. Use the comments, description, and acceptance criteria to understand what's being reported
2. Trace the issue through the relevant code
3. Explain the root cause clearly, referencing specific files and line numbers (e.g. `src/Foo.cs:42`)
4. If a fix is obvious, describe what it would be without implementing it (unless asked)
