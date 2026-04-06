---
name: sdl-ticket-fetcher
description: "SDL Phase 0: Fetches an Azure DevOps work item with full parent chain traversal, comments, and screenshots. Writes agent-state/TICKET.md."
tools: Bash, Read, Write
---

You are fetching an Azure DevOps work item and writing a comprehensive ticket summary.

The prompt will provide:
- **Ticket number** (required)
- **Extra context** (optional)

## Step 1 — Detect ADO Org and Project

Parse the org and project from the git remote URL:
```
git remote get-url origin
```
Supported formats:
- SSH: `git@ssh.dev.azure.com:v3/{org}/{project}/{repo}`
- HTTPS: `https://dev.azure.com/{org}/{project}/_git/{repo}`
- HTTPS legacy: `https://{org}@dev.azure.com/{org}/{project}/_git/{repo}`

URL-decode the project name (e.g. `MAU%20DEX` -> `MAU DEX`).

Fallback: If the remote is not an Azure DevOps URL, check `az devops configure --list`. Always prefer the git remote.

## Step 2 — Fetch Work Item and Comments (in parallel)

Work item:
```
az boards work-item show --id {ticket} --org https://dev.azure.com/{org}
```
Comments:
```
az devops invoke --area wit --resource comments --route-parameters project="{project}" workItemId={ticket} --org https://dev.azure.com/{org} --api-version "7.1-preview"
```
Screenshots: Scan `System.Description` HTML for `<img src="...">` tags. For each:
```
TOKEN=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
curl -s -L "{image_url}" -H "Authorization: Bearer $TOKEN" -o /tmp/ticket-{ticket}-image-{n}.png
```
Then read each downloaded image with the Read tool.

## Step 3 — Traverse Parent Tickets

Check `relations` for `rel === "System.LinkTypes.Hierarchy-Reverse"` (parent link). Parent ID = last path segment of relation URL. Fetch each parent and its comments. Continue up until no parent exists.

## Step 4 — Write Summary

Create `agent-state/` directory if needed. Check if `agent-state/` is in `.gitignore` — if not, append it.

Write `agent-state/TICKET.md` with:
- Ancestry chain (type, title, state, one-sentence summary per ancestor)
- Target ticket: title, type, state, assigned to, full description, all acceptance criteria verbatim, testing notes
- Comments (author, date, content)
- Screenshot descriptions
- Parent context if relevant

Return a brief summary of the ticket (title, type, key acceptance criteria).
