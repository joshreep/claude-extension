# joshreep-tools

A Claude Code plugin providing Azure DevOps workflow automation, PR management, SDL pipeline orchestration, code review, and sprint demo planning.

## Skills

| Skill | Description |
|-------|-------------|
| `/joshreep-tools:pr` | Create a pull request or retrieve PR feedback/build status. Supports GitHub (`gh`) and Azure DevOps (`az repos`). |
| `/joshreep-tools:sdl` | Multi-agent SDL pipeline: fetches a ticket, plans, implements, reviews, tests, and audits — with mandatory user checkpoints. |
| `/joshreep-tools:sdl-init` | Discover and cache project stack for the SDL pipeline. Run once per project to accelerate subsequent `/sdl` runs. |
| `/joshreep-tools:ticket` | Fetch and summarize an Azure DevOps work item with full parent chain, comments, and screenshots. Can also explain or implement the fix. |
| `/joshreep-tools:code-review-assistant` | Comprehensive branch-vs-branch code review with 17-point evaluation criteria. |
| `/joshreep-tools:demo-plan` | Build a step-by-step sprint demo plan from Azure DevOps tickets in specified board columns. |

## Prerequisites

- **Azure CLI** (`az`) with the `azure-devops` extension — required for `/ticket`, `/sdl`, `/demo-plan`, and ADO-flavored `/pr`
- **GitHub CLI** (`gh`) — required for GitHub-flavored `/pr` and `/code-review-assistant`

## Installation

### From a marketplace (if added)

```
/plugin marketplace add joshreep/claude-extension
/plugin install joshreep-tools@joshreep/claude-extension
```

### For local development/testing

```bash
claude --plugin-dir /path/to/claude-extension
```

## Usage Examples

```
/joshreep-tools:pr                    # Create a PR for the current branch
/joshreep-tools:pr --draft            # Create a draft PR
/joshreep-tools:pr 2221              # Get feedback/build status for PR #2221
/joshreep-tools:ticket 5275          # Summarize ADO work item #5275
/joshreep-tools:ticket 5275 fix      # Implement the fix for #5275
/joshreep-tools:sdl-init              # Discover project stack (run once per project)
/joshreep-tools:sdl-init --refresh    # Re-discover project stack (overwrite existing)
/joshreep-tools:sdl 5275             # Full SDL pipeline for ticket #5275
/joshreep-tools:code-review-assistant feature/my-branch develop
/joshreep-tools:demo-plan "In UAT, Dev Complete"
```
