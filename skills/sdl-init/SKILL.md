---
name: sdl-init
description: "Discover and cache project stack profile for the SDL pipeline. Detects languages, frameworks, build/test/lint commands, test conventions, and source control. Writes .claude/sdl-project.md."
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write
argument-hint: "[--refresh]"
context: inherit
---

You are initializing the SDL project profile. This one-time discovery caches the project's tech stack, build commands, test conventions, and source control info so that subsequent `/sdl` pipeline runs skip expensive re-discovery.

The user invoked this with: $ARGUMENTS

## Step 1 — Parse Arguments

Extract from `$ARGUMENTS`:
- **`--refresh`** (optional flag): if present, overwrite the existing profile without asking

Check if `.claude/sdl-project.md` already exists:
- If it exists and `--refresh` was **not** passed: inform the user that a profile already exists and ask whether to overwrite or abort. Wait for their response.
- If it exists and `--refresh` **was** passed: note that the existing profile will be overwritten, proceed without asking.
- If it does not exist: proceed normally.

## Step 2 — Ensure `.claude/` Directory Exists

```bash
mkdir -p .claude
```

## Step 3 — Detect Source Control

Parse `git remote get-url origin` to determine the remote type and extract org/project/repo.

**Supported formats:**
- **ADO SSH**: `git@ssh.dev.azure.com:v3/{org}/{project}/{repo}`
- **ADO HTTPS**: `https://dev.azure.com/{org}/{project}/_git/{repo}`
- **ADO HTTPS legacy**: `https://{org}@dev.azure.com/{org}/{project}/_git/{repo}`
- **GitHub SSH**: `git@github.com:{org}/{repo}.git`
- **GitHub HTTPS**: `https://github.com/{org}/{repo}.git`

URL-decode the project name (e.g. `MAU%20DEX` → `MAU DEX`).

**Fallback**: If the remote is not an Azure DevOps URL, check `az devops configure --list` for configured defaults. Always prefer the git remote.

Also detect the default branch:
```bash
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'
```
If that fails, check for `main` or `master` or `develop` branches.

## Step 4 — Read Existing Documentation

Read these files if they exist (skip any that are missing):
- Root-level `README.md`, `CLAUDE.md`, `.claude/CLAUDE.md`
- `ClientApp/README.md`, `ClientApp/TESTING.md`
- Any `*.md` files in a `docs/` directory

These provide baseline understanding. Use file-system exploration in Step 5 to fill gaps and verify.

## Step 5 — Discover Project Stack

Examine actual project files to detect the full tech stack. Be thorough — this only runs once per project.

### 5a. Languages & Frameworks

Search for manifest files to identify languages and frameworks:
- `package.json` → Node.js / frontend framework (React, Angular, Vue, Next.js, etc.)
- `*.csproj`, `*.sln` → .NET / ASP.NET Core
- `requirements.txt`, `pyproject.toml`, `setup.py` → Python
- `go.mod` → Go
- `Cargo.toml` → Rust
- `pom.xml`, `build.gradle` → Java
- `*.fsproj` → F#

Read the relevant manifest files to identify specific frameworks and versions.

### 5b. Solution/Project Root

Identify the solution file or project root relative to the repo root (e.g., `DexTos.sln`, root `package.json`).

### 5c. Build Commands

Derive exact, copy-pasteable build commands:
- Check `package.json` `scripts` for build commands
- Check for `*.sln` or `*.csproj` files → `dotnet build {file}`
- Check for `Makefile`, `Dockerfile`, CI config files (`.github/workflows/`, `azure-pipelines.yml`)
- Verify the command works by inspecting the project structure (do NOT run it)

### 5d. Test Commands & Conventions

Find test directories and configuration:
- Search for directories: `*Test*`, `*test*`, `*spec*`, `__tests__`, `*.Tests`, `*.UnitTest*`
- Read test configuration files: `jest.config.*`, `karma.conf.*`, `vitest.config.*`, `xunit.runner.*`, `pytest.ini`, `.nunit`
- Sample 2-3 existing test files to determine:
  - Assertion library (e.g., Jest expect, xUnit Assert, NUnit Assert, pytest assert)
  - Mock library (e.g., jest.mock, Moq, NSubstitute, unittest.mock)
  - Setup/teardown patterns (beforeEach, [SetUp], fixtures)
  - Test file naming convention (e.g., `*.spec.ts`, `*Tests.cs`, `test_*.py`)

Derive exact test commands with CI-appropriate flags:
- **Backend**: e.g., `dotnet test DexTosUnitTest/`, `pytest tests/`
- **Frontend**: e.g., `cd ClientApp && npm run test -- --watch=false`

Separate backend and frontend test commands if applicable.

### 5e. Lint/Typecheck Commands

Detect static analysis tools and derive commands:
- `.eslintrc*`, `eslint.config.*` → `npx eslint .` (or scoped path)
- `tsconfig.json` → `npx tsc --noEmit`
- `.prettierrc*` → `npx prettier --check .`
- StyleCop / FxCopAnalyzers in `*.csproj` → `dotnet format --verify-no-changes`
- `.editorconfig` → note its presence

### 5f. E2E Test Framework

Check for existing E2E setup:
- `playwright.config.*` → Playwright
- `cypress.config.*`, `cypress/` → Cypress
- `protractor.conf.*` → Protractor

If found: identify the framework and derive the exact run command.
If not found: note `NO_E2E_FRAMEWORK` and recommend one (Playwright for web apps, supertest for API-only).

### 5g. Database Technology & Migration Patterns

Detect database tech:
- `Migrations/` directory, `DbContext` classes → Entity Framework (find the DB provider in `*.csproj` or `Startup.cs`/`Program.cs`)
- `prisma/schema.prisma` → Prisma
- `knexfile.*` → Knex.js
- `alembic/`, `alembic.ini` → Alembic (SQLAlchemy)
- `flyway/` → Flyway
- Connection strings in config files → identify DB type (SQL Server, PostgreSQL, MySQL, SQLite, MongoDB)

Note the migration pattern (code-first, DB-first, etc.).

### 5h. Dev Server URLs & Startup Commands

Find dev server configuration:
- `Properties/launchSettings.json` → `applicationUrl` for ASP.NET
- `package.json` scripts → `start`, `serve`, `dev` commands and their ports
- `angular.json` → `serve.options.port`
- `vite.config.*`, `next.config.*` → port configuration
- `.env`, `.env.development` → `PORT` variable (do not include secrets, just the port)

Record:
- Backend URL (e.g., `https://localhost:44369`)
- Frontend URL (e.g., `http://localhost:4200`)
- Startup commands for each (e.g., `dotnet run --project DexTos/`, `cd ClientApp && npm start`)

### 5i. Architecture Notes

Describe the project's architecture briefly:
- General pattern (MVC, Clean Architecture, monorepo, microservices, etc.)
- Key directory organization (e.g., "backend in root, frontend in ClientApp/")
- Any notable patterns observed (dependency injection, repository pattern, CQRS, etc.)

## Step 6 — Write the Profile

Write the discovered information to `.claude/sdl-project.md` using this format:

```markdown
# SDL Project Profile

> Auto-generated by `/sdl-init` on {YYYY-MM-DD}. Re-run `/sdl-init --refresh` to update.
>
> profile-version: 1

## Source Control

- **Remote type**: {Azure DevOps | GitHub}
- **Organization**: {org}
- **Project**: {project} (ADO only, omit for GitHub)
- **Repository**: {repo}
- **Org URL**: {https://dev.azure.com/{org} or https://github.com/{org}}
- **Default branch**: {main|master|develop}

## Project Stack

- **Solution/project root**: {path relative to repo root}
- **Languages**: {e.g., C#, TypeScript}
- **Backend framework**: {e.g., ASP.NET Core 8.0}
- **Frontend framework**: {e.g., Angular 17}
- **Build command**: `{exact command}`
- **Backend test command**: `{exact command with CI flags}`
- **Frontend test command**: `{exact command with CI flags}`
- **Lint/typecheck commands**:
  - `{command 1}`
  - `{command 2}`
- **E2E test command**: `{exact command}` | `NO_E2E_FRAMEWORK — recommending: {framework}`
- **Test file placement**: {where tests live and naming convention}
- **Test patterns**: {assertion library, mock library, setup/teardown patterns — with example file paths}
- **DB technology**: {e.g., SQL Server via Entity Framework Core}
- **DB migration pattern**: {e.g., Code-first EF migrations in Migrations/}

## Dev Servers

- **Backend URL**: `{url}` (from {source})
- **Frontend URL**: `{url}` (from {source})
- **Startup commands**:
  - Backend: `{command}`
  - Frontend: `{command}`

## Architecture Notes

{Brief description of the project's architecture, key directories, and patterns}
```

Omit any section or field where the information was not found (e.g., if no database, omit the DB fields). Do not invent values — only record what was actually discovered.

## Step 7 — Present Summary

Display a concise summary to the user:
1. Languages and frameworks detected
2. Key commands (build, test, lint)
3. E2E framework status
4. The file path where the profile was written

Remind the user that subsequent `/sdl` runs will use this profile to skip project discovery, and that they can run `/sdl-init --refresh` if the project stack changes.
