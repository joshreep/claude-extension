# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

This is a Claude Code plugin (`joshreep-tools`) that packages reusable slash commands and skills for Azure DevOps workflow automation, PR management, and code review. It is distributed via the Claude Code plugin/marketplace system.

## Plugin Structure

- `.claude-plugin/plugin.json` — plugin manifest (name, version, description)
- `skills/` — each subdirectory contains a `SKILL.md` with YAML frontmatter and markdown instructions
  - `pr/` — pull request creation and feedback retrieval (GitHub + Azure DevOps)
  - `sdl/` — multi-agent Software Development Lifecycle pipeline
  - `ticket/` — Azure DevOps work item fetcher and summarizer
  - `code-review-assistant/` — branch-comparison code review
  - `demo-plan/` — sprint demo plan generator from ADO board columns

## Key Conventions

- All skills use `SKILL.md` format with YAML frontmatter (`name`, `description`, `user-invocable`, `allowed-tools`, `argument-hint`, `context`)
- Skills reference `$ARGUMENTS` for user-provided input
- ADO-related skills detect org/project from `git remote get-url origin` with fallback to `az devops configure`
- The `sdl` skill orchestrates subagents via the Agent tool and communicates state through `agent-state/*.md` files

## Testing Changes

Load the plugin locally to test:

```bash
claude --plugin-dir ./
```

Then invoke skills like `/joshreep-tools:pr`, `/joshreep-tools:ticket 12345`, etc. to verify behavior.

## Versioning

Update the `version` field in `.claude-plugin/plugin.json` when releasing changes (semver).
