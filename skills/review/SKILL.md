---
name: review
description: Composite code review — fetches ticket context, PR feedback, and performs a comprehensive diff review cross-referenced against requirements.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Agent
argument-hint: "<ticket-number> [PR_ID | feature-branch] [base-branch]"
context: inherit
---

# Composite Code Review

You are performing a comprehensive code review that cross-references ticket requirements, PR feedback, and the actual diff. The user invoked this with: $ARGUMENTS

## Step 1: Parse Arguments

Extract from `$ARGUMENTS`:
- **Ticket number** (required): numeric work item ID
- **PR ID or feature branch** (optional): if numeric, treat as PR ID. If it looks like a branch name (contains `/` or matches a git ref), treat as feature branch.
- **Base branch** (optional): base branch to diff against. Default: auto-detect

When a PR ID is provided, the feature and base branches will be extracted from the PR metadata in Step 3 — no need for the user to specify them separately.

## Step 2: Fetch Ticket Context

Create state directory: `mkdir -p /tmp/joshreep-tools/{ticket}`

Launch `joshreep-tools:sdl-ticket-fetcher` agent with prompt:

> **Ticket number**: {ticket}
> **State directory**: `/tmp/joshreep-tools/{ticket}/`

After completion, read `/tmp/joshreep-tools/{ticket}/TICKET.md`. Store the ticket context — especially acceptance criteria — for use in the review evaluation.

## Step 3: Fetch PR Feedback (if PR_ID provided)

Skip this step entirely if no PR ID was provided.

### 3a — Parse remote details

Run `git remote get-url origin` and extract ORG, PROJECT, REPO:

**GitHub** — URL contains `github.com`:
- SSH: `git@github.com:ORG/REPO.git`
- HTTPS: `https://github.com/ORG/REPO.git`

**Azure DevOps** — URL contains `dev.azure.com`:
- SSH: `git@ssh.dev.azure.com:v3/ORG/PROJECT/REPO`
- HTTPS: `https://ORG@dev.azure.com/ORG/PROJECT/_git/REPO`
- URL-decode percent-encoded characters (e.g. `%20` → space)

### 3b — Extract branches from PR metadata

**GitHub:**
```
gh api repos/ORG/REPO/pulls/PR_ID --jq '{head: .head.ref, base: .base.ref}'
```

**Azure DevOps:**
```
az repos pr show --id PR_ID --org "https://dev.azure.com/ORG" --query '{sourceBranch: sourceRefName, targetBranch: targetRefName}' -o json
```
Strip `refs/heads/` prefix from ADO branch names. Use these as the feature branch and base branch for Step 4 (overriding any auto-detection).

### 3c — Fetch PR threads

**GitHub:**
```
gh api repos/ORG/REPO/pulls/PR_ID/comments \
  --jq '.[] | "--- Comment \(.id) by \(.user.login) ---\n\(.body)\n"'
```
```
gh api repos/ORG/REPO/pulls/PR_ID/reviews \
  --jq '.[] | select(.body != "") | "--- Review by \(.user.login) [\(.state)] ---\n\(.body)\n"'
```

**Azure DevOps:**
```
TOKEN=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://dev.azure.com/ORG/PROJECT/_apis/git/repositories/REPO/pullRequests/PR_ID/threads?api-version=7.1"
```
Parse the JSON and extract non-system comments with author, thread ID, and status.

### 3d — Check build status

**GitHub:**
```
gh api repos/ORG/REPO/pulls/PR_ID --jq '.head.sha'
```
Then:
```
gh api repos/ORG/REPO/commits/SHA/check-runs \
  --jq '.check_runs[] | select(.conclusion == "failure") | "--- \(.name) [FAILED] ---\n\(.output.summary // "No summary")\n"'
```

**Azure DevOps:**
```
az pipelines build list \
  --org "https://dev.azure.com/ORG" \
  --project "PROJECT" \
  --reason pullRequest \
  --top 5 \
  --query "sort_by([?contains(sourceBranch, 'PR_ID')], &finishTime) | reverse(@)" \
  -o json
```
For failed builds, fetch details:
```
az pipelines build show --id BUILD_ID --org "https://dev.azure.com/ORG" --project "PROJECT" -o json
```
Check `validationResults` first, then timeline for failed records, then build logs as fallback.

### 3e — Organize feedback

Group into:
- **Build Status**: Most recent build result. If failed, include specific errors.
- **Review Feedback**: PR thread comments grouped by thread with status indicators (active/fixed/closed/wontFix).

## Step 4: Code Review

### 4a — Setup and branch validation

Run `git fetch origin` to ensure remote refs are up to date.

Determine the feature branch and base branch using this priority:
1. **PR-derived** (from Step 3b): if a PR ID was provided, use the source/target branches extracted from PR metadata.
2. **User-provided arguments**: explicit feature-branch and/or base-branch from Step 1.
3. **Auto-detect feature branch**: `git branch --show-current`
4. **Auto-detect base branch** (try in order):
   - GitHub: `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`
   - Azure DevOps: `az repos show --org "https://dev.azure.com/ORG" --project "PROJECT" --repository "REPO" --query defaultBranch --output tsv` (strip `refs/heads/` prefix)
   - `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'`
   - Heuristic: check which of `develop`, `main`, `master` exists on remote

Normalize branches to remote refs where possible (prefer `origin/branch` over local `branch`).

Get the list of changed files:
```
git diff --name-only --diff-filter=AM origin/BASE...origin/FEATURE
```

If no changes are found, report that and stop.

### 4b — Analyze the diff

> **CRITICAL — Branch Isolation Rule**: The local working directory may reflect a different branch. This means:
> - **NEVER** use the `Read` tool, `Grep` tool, or `Glob` tool to inspect source files — they read from the local working directory which may be the wrong branch.
> - **ALWAYS** use `git show "FEATURE:FILE_PATH"` via Bash to read file content.
> - **ALWAYS** use `git diff` to view changes.

For each changed file:
```
git diff origin/BASE...origin/FEATURE -- "FILE_PATH"
```

For full file context:
```
git show "origin/FEATURE:FILE_PATH"
```

### 4c — Evaluation criteria

Evaluate each change against:

- **Design & Architecture**: Fits system patterns, avoids coupling, clear separation of concerns.
- **Complexity & Maintainability**: Flat control flow, low cyclomatic complexity, DRY, no dead code.
- **Functionality & Correctness**: Correct under valid/invalid inputs, all edge cases, robust error handling.
- **Readability & Naming**: Identifiers convey intent, comments explain why not what, no hidden side-effects.
- **Best Practices & Patterns**: Language/framework idioms, SOLID principles, proper resource cleanup.
- **Test Coverage & Quality**: Unit + integration tests, both success and failure paths, meaningful assertions.
- **Standardization & Style**: Style guide conformance, consistent structure, no new linter warnings.
- **Documentation**: Public APIs documented, user-facing docs updated where visible changes occurred.
- **Security & Compliance**: Input validation, output encoding, secrets management, authZ/authN enforcement.
- **Performance & Scalability**: No N+1 queries, no unnecessary re-renders, appropriate caching/batching.
- **Observability & Logging**: Key events emit metrics/traces, appropriate log levels, no sensitive data in logs.
- **Breaking Changes & Backwards Compatibility**: API/schema/config changes that could break consumers.
- **Dependency Updates**: Version pins appropriate, no known vulnerabilities, breaking changes handled.
- **Ticket Requirements Alignment**: Cross-reference every acceptance criterion from the ticket against the diff. Flag acceptance criteria that appear unaddressed. Flag changes that don't trace back to any requirement (scope creep).

### 4d — Report issues

For each validated issue:

- **File**: `<path>:<line-range>`
  - **Issue**: One-line summary of the root problem
  - **Fix**: Concise suggested change or code snippet
  - **Severity**: Critical / Major / Minor / Enhancement

## Step 5: Final Report

Present the complete review as a single report:

### High-Level Summary

In 2-3 sentences: product impact, engineering approach, change scope.

### Prioritized Issues

Group by severity (Critical → Major → Minor → Enhancement):

#### Critical
Security vulnerabilities, data loss, system crashes, breaking changes without migration.

#### Major
Functionality correctness, performance at scale, maintainability, test coverage gaps.

#### Minor
Code style, non-critical edge cases, readability, documentation gaps.

#### Enhancement
Code organization, non-critical optimizations, developer experience.

### Highlights

Brief bulleted list of positive findings — good patterns, clean implementations, thorough testing.

### Ticket Coverage Analysis

For each acceptance criterion from the ticket:
- **Addressed** / **Partially Addressed** / **Not Addressed** / **Not Applicable**
- If PR feedback exists, note unresolved review threads that relate to unmet criteria.

### Testing & Deployment Recommendations

If critical or major issues found: specific test scenarios, manual QA steps, deployment considerations.

### Summary Checklist

- [ ] All tests passing?
- [ ] No security vulnerabilities introduced?
- [ ] Breaking changes documented?
- [ ] Performance impact acceptable?
- [ ] Documentation updated?
- [ ] All acceptance criteria addressed?
- [ ] Ready to merge?
