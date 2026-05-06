# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

This is a Claude Code plugin (`joshreep-tools`) that packages reusable slash commands and skills for Azure DevOps workflow automation, PR management, and code review. It is distributed via the Claude Code plugin/marketplace system.

## Plugin Structure

- `.claude-plugin/plugin.json` — plugin manifest (name, version, description)
- `skills/` — each subdirectory contains a `SKILL.md` with YAML frontmatter and markdown instructions
  - `pr/` — pull request creation and feedback retrieval (GitHub + Azure DevOps)
  - `sdl/` — multi-agent SDL pipeline orchestrator (delegates to agents below)
  - `sdl-init/` — project stack discovery and caching for SDL pipeline acceleration
  - `ticket/` — Azure DevOps work item fetcher and summarizer
  - `code-review-assistant/` — branch-comparison code review
  - `review/` — composite review: ticket context + PR feedback + code review in one pass
  - `demo-plan/` — sprint demo plan generator from ADO board columns
  - `sdl-retro/` — retrospective analysis of SDL pipeline runs
- `agents/` — reusable agent definitions (markdown with YAML frontmatter)
  - `sdl-ticket-fetcher.md` — ADO work item fetching (shared by SDL pipeline, ticket skill, and review skill)
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
- The `sdl` skill is a thin orchestrator that delegates to `joshreep-tools:sdl-*` agents and manages flow control, user checkpoints, and state file handoffs via `agent-state/{ticket}/*.md` (namespaced per ticket to prevent cross-run overwrites). It also writes `agent-state/{ticket}/TOKEN_USAGE.md` with per-phase token counts, cost estimates, and efficiency metrics for analysis by `sdl-retro`.

## Testing Changes

Load the plugin locally to test:

```bash
claude --plugin-dir ./
```

Then invoke skills like `/joshreep-tools:pr`, `/joshreep-tools:ticket 12345`, etc. to verify behavior.

## Versioning

Versioning is automated via [release-please](https://github.com/googleapis/release-please). Use conventional commit prefixes:
- `feat:` → minor bump
- `fix:` → patch bump
- `feat!:` or `BREAKING CHANGE:` → major bump

When commits land on `main` (via merged PRs from `dev`), release-please opens a release PR that bumps versions in `plugin.json` and `marketplace.json` and generates `CHANGELOG.md`. Merge the release PR to tag the release.

Do **not** manually edit version numbers in `plugin.json` or `marketplace.json`.
