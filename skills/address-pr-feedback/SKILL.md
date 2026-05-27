---
name: address-pr-feedback
description: "Triage PR review feedback: for each comment, either propose a concrete fix or provide a clear explanation of why no change is needed."
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "<feedback text or 'paste'>"
context: inherit
---

You are triaging pull request review feedback. The user invoked this with: $ARGUMENTS

## Step 1 — Collect the Feedback

If `$ARGUMENTS` contains the feedback inline, use it directly.

If `$ARGUMENTS` is empty or the word `paste`, tell the user: "Paste the PR feedback below and I'll address each comment." Wait for their input before continuing.

## Step 2 — Parse the Feedback Into Items

Split the feedback into individual review comments. Each distinct comment, thread, or bullet point is one item. Number them.

If the feedback references specific file paths or line numbers, note them alongside each item.

## Step 3 — Gather Context

For each item, determine what context is needed to respond:

1. **Get the current diff** to understand what was changed:
   ```bash
   git merge-base HEAD develop 2>/dev/null || git merge-base HEAD main
   ```
   Then:
   ```bash
   git diff <merge-base>..HEAD
   ```

2. **If an item references a specific file**, read that file in full for surrounding context — use `git show HEAD:<file>` rather than the Read tool to ensure you're reading the committed version.

3. **If an item references a line that no longer exists** (common when the reviewer's comment is stale), note that the code has since changed and describe what changed.

## Step 4 — Triage Each Item

For each numbered item, produce one of two responses:

### Option A — Fix Proposed

When the feedback identifies a genuine issue:

> **Item N — Fix**
>
> *Reviewer's concern:* [one-sentence summary of what the reviewer flagged]
>
> *Proposed change:*
> ```[language]
> [exact code change — show the before and after, or a replacement block]
> ```
> *File:* `path/to/file.ext` (line N if applicable)

### Option B — No Change Needed

When the feedback is addressed by existing code, based on a misunderstanding, out of scope, or a deliberate tradeoff:

> **Item N — No change needed**
>
> *Reviewer's concern:* [one-sentence summary]
>
> *Explanation:* [clear, direct explanation — reference specific code, line numbers, or design rationale. Do NOT be dismissive. If it's a tradeoff, name it.]

### Calibration rules

- **Do not propose a change just to appear responsive.** If the code is correct, say so and explain why.
- **Do not dismiss feedback without evidence.** If you say "no change needed," cite the specific code or reasoning that backs it up.
- **If you're unsure**, say so explicitly and ask a clarifying question rather than guessing.
- **Severity matters**: treat Critical/Major feedback as requiring a fix unless there is a strong explicit reason not to. Minor/Enhancement feedback warrants more discretion.

## Step 5 — Summary

After triaging all items, present a summary table:

| # | Reviewer Comment (short) | Disposition | File |
|---|--------------------------|-------------|------|
| 1 | ... | Fix / No change | ... |
| 2 | ... | Fix / No change | ... |

Then ask: "Should I apply the proposed fixes now, or would you like to review them first?"

If the user confirms, apply all Fix items in one pass using the Edit tool.
