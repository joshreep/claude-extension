# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

This is a Claude Code plugin (`joshreep-tools`) that packages reusable slash commands and skills for Azure DevOps workflow automation, PR management, and code review. It is distributed via the Claude Code plugin/marketplace system.

## Plugin Structure

- `.claude-plugin/plugin.json` — plugin manifest (name, version, description)
- `skills/` — each subdirectory contains a `SKILL.md` with YAML frontmatter and markdown instructions
  - `pr/` — pull request creation and feedback retrieval (GitHub + Azure DevOps)
  - `sdl/` — multi-agent SDL pipeline orchestrator (delegates to agents below)
  - `ticket/` — Azure DevOps work item fetcher and summarizer
  - `code-review-assistant/` — branch-comparison code review
  - `demo-plan/` — sprint demo plan generator from ADO board columns
  - `sdl-retro/` — retrospective analysis of SDL pipeline runs
- `agents/` — reusable agent definitions (markdown with YAML frontmatter)
  - `sdl-ticket-fetcher.md` — Phase 0: ADO work item fetching
  - `sdl-architect.md` — Phase 1a: project discovery and plan drafting
  - `sdl-implementer.md` — Phase 2: code implementation
  - `sdl-reviewer.md` — Phase 3: code review
  - `sdl-e2e-tester.md` — Phase 4: end-to-end testing
  - `sdl-auditor.md` — Phase 5a: final quality audit

## Key Conventions

- All skills use `SKILL.md` format with YAML frontmatter (`name`, `description`, `user-invocable`, `allowed-tools`, `argument-hint`, `context`)
- Agent definitions use `.md` files with YAML frontmatter (`name`, `description`, `tools`, `model`) in the `agents/` directory
- Skills reference `$ARGUMENTS` for user-provided input
- ADO-related skills detect org/project from `git remote get-url origin` with fallback to `az devops configure`
- The `sdl` skill is a thin orchestrator that delegates to `joshreep-tools:sdl-*` agents and manages flow control, user checkpoints, and state file handoffs via `agent-state/*.md`

## Testing Changes

Load the plugin locally to test:

```bash
claude --plugin-dir ./
```

Then invoke skills like `/joshreep-tools:pr`, `/joshreep-tools:ticket 12345`, etc. to verify behavior.

## Versioning

Update the `version` field in `.claude-plugin/plugin.json` when releasing changes (semver).
