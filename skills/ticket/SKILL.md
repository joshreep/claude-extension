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

## Step 2: Fetch Ticket

Create the state directory: `mkdir -p /tmp/joshreep-tools/{ticket}`

Launch the `joshreep-tools:sdl-ticket-fetcher` agent with prompt:

> **Ticket number**: {ticket}
> **State directory**: `/tmp/joshreep-tools/{ticket}/`
> **Extra context**: {extra_context if any}

After the agent completes, read `/tmp/joshreep-tools/{ticket}/TICKET.md` to get the full ticket summary including ancestry chain, description, acceptance criteria, comments, and screenshot descriptions.

## Step 3: Present the Ticket

Present the contents of TICKET.md to the user. The agent has already structured it with ancestry chain, full ticket details, comments, and screenshot descriptions.

## Step 4: Determine Mode

**If extra context was provided**, use it to determine intent:
- A person's name → focus on that person's comments and explain what they're reporting
- Words like "explain", "what's happening", "why" → explain the issue by tracing it through the codebase
- Words like "fix", "implement", "complete", "do it", "work on it" → implement the solution

**If only a ticket number was given**, ask the user:
> "Would you like me to explain the issue/requirements, or should I implement the fix?"

## Step 5: Implementing a Fix

If the user wants you to implement:

1. Read all relevant files before touching anything — never modify code you haven't read
2. Understand existing patterns in the codebase before writing new code
3. Make only the changes necessary to satisfy the acceptance criteria
4. Do not refactor surrounding code, add comments, or over-engineer
5. When done, summarize what was changed and why

## Step 6: Explaining an Issue

If the user wants an explanation:

1. Use the comments, description, and acceptance criteria to understand what's being reported
2. Trace the issue through the relevant code
3. Explain the root cause clearly, referencing specific files and line numbers (e.g. `src/Foo.cs:42`)
4. If a fix is obvious, describe what it would be without implementing it (unless asked)
