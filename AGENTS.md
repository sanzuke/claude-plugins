# Repository Guidelines

## Project Overview

Internal Claude Code **plugin marketplace** for QTI Engineering (`qti-plugins`). It is not
an application — there is no runtime service, no build artifact, no compiled output. The
repo's job is to declare a marketplace manifest and host plugin sources that teams install
into their own projects via the `claude` CLI. All prose (README, SKILL.md, templates) is
written in Indonesian for an internal audience.

Two plugins ship today:

- **`sop-projek-baru`** ("new-project SOP") — keeps architecture/documentation hygiene
  alive in *consumer* repos: ADRs, living domain docs (business-flow, glossary),
  CHANGELOG, and a lean `CLAUDE.md`.
- **`qa-automation`** — QA Automation Engineer SOP: scaffolds a Playwright (TypeScript)
  suite, enforces anti-flaky test conventions, and reports run results into Huly Test
  Management via the `huly_*` MCP tools.

## Architecture & Data Flow

```
qti-plugins (this repo)                 consumer repo (any team's project)
├─ .claude-plugin/marketplace.json      ├─ .claude/settings.json
│   lists plugins[] {name, source}      │   extraKnownMarketplaces.qti-plugins
├─ plugins/sop-projek-baru/             │   enabledPlugins["<plugin>@qti-plugins"]
└─ plugins/qa-automation/               └─ (auto-registers marketplace on trust,
   ├─ .claude-plugin/plugin.json            no install prompt)
   └─ skills/<skill-name>/
      ├─ SKILL.md   (agent playbook, frontmatter = auto-trigger matcher)
      ├─ scripts/   (idempotent generators / result parsers)
      └─ assets/    (templates copied into the consumer repo)
```

Flow: a maintainer edits a plugin under `plugins/<name>/`, registers it in
`.claude-plugin/marketplace.json`, validates, and pushes. Downstream users either run
`claude plugin install …` manually, or get it automatically via a committed
`.claude/settings.json` (see `contoh-settings-repo-projek/`). Once installed, each skill's
long, scenario-dense `description:` frontmatter makes Claude **auto-activate** it from
conversational context (new repo, architecture decision, "write a test for this") — the
slash command `/<plugin>:<skill>` is only a manual fallback. When active, a skill runs its
own `scripts/` against the *consumer* repo, materializing `assets/` templates without ever
overwriting existing files.

`qa-automation` additionally closes a loop outside the repo: `playwright test` writes
`test-results/results.json`, `scripts/huly-report.mjs` turns it into title→status rows, and
the agent pushes those into an existing Huly test run with `huly_set_test_result`. Huly test
cases carry opaque ids, so **matching is by exact test title == Huly test case name**; test
runs can only be created in the Huly UI, never from MCP.

## Key Directories

Repo root layout (the structure Claude Code's plugin loader expects):

```
.claude-plugin/marketplace.json
contoh-settings-repo-projek/.claude/settings.json
plugins/sop-projek-baru/
  .claude-plugin/plugin.json
  skills/sop-projek-baru/{SKILL.md,scripts/scaffold.sh,assets/*.md}
plugins/qa-automation/
  .claude-plugin/plugin.json
  skills/qa-automation/{SKILL.md,scripts/{scaffold-playwright.sh,huly-report.mjs},assets/*}
```

| Path | Purpose |
|---|---|
| `.claude-plugin/marketplace.json` | Marketplace manifest. **Must** live under `.claude-plugin/` — a copy at repo root is not discovered (`claude plugin validate .` fails with "No manifest found in directory"). |
| `contoh-settings-repo-projek/.claude/settings.json` | Copy-paste **example** for a consuming project's own `.claude/settings.json`. Not this repo's own settings. |
| `plugins/<plugin-name>/` | One directory per plugin. Must contain `.claude-plugin/plugin.json` plus any of `skills/`, `commands/`, `agents/`, `hooks/`. |
| `plugins/sop-projek-baru/skills/sop-projek-baru/` | Docs SOP skill: `SKILL.md`, `scripts/scaffold.sh`, `assets/` (5 Markdown templates). |
| `plugins/qa-automation/skills/qa-automation/` | QA SOP skill: `SKILL.md`, `scripts/scaffold-playwright.sh`, `scripts/huly-report.mjs`, `assets/` (Playwright config, fixtures, page object, spec, CI workflow, QA checklist). |

## Development Commands

There is no build/test/lint tooling — the "tooling" is the `claude` CLI itself:

```bash
# Validate marketplace + plugin manifests (run from repo root)
claude plugin validate .

# Install this marketplace locally for a smoke test before pushing
claude plugin marketplace add ./claude-plugins

# End-user flow (from a consumer repo)
claude plugin marketplace add sanzuke/claude-plugins
claude plugin install sop-projek-baru@qti-plugins
claude plugin install qa-automation@qti-plugins
claude plugin marketplace update   # refresh cached marketplace after a push

# Scaffolders (normally invoked by the skills themselves, against a *target* repo)
bash plugins/sop-projek-baru/skills/sop-projek-baru/scripts/scaffold.sh [target-dir]
bash plugins/qa-automation/skills/qa-automation/scripts/scaffold-playwright.sh [target-dir]

# Turn a Playwright JSON report into Huly-ready rows
node plugins/qa-automation/skills/qa-automation/scripts/huly-report.mjs test-results/results.json [--json]
```

If an install summary says `Run /reload-plugins to activate.`, run that command next.

## Code Conventions & Common Patterns

- **Naming triad**: plugin directory name == `plugin.json` `name` == skill directory name
  == `SKILL.md` frontmatter `name` (e.g. all four are `qa-automation`, kebab-case). This is
  what makes the slash command `/<plugin-name>:<skill-name>` resolve.
- **SKILL.md frontmatter is a trigger matcher, not a summary.** `description:` is written
  as a long, keyword-dense paragraph enumerating concrete activation scenarios, and
  explicitly tells the agent not to wait for magic words ("ADR", "dokumentasi", "SOP").
  Follow this style for any new skill.
- **Minimal manifests.** `plugin.json` only carries `name`, `displayName`, `description`,
  `author`, `keywords` — no `version`, `license`, `main`, or `commands`/`hooks` fields
  unless actually needed.
- **Never set `version` in `plugin.json` or the marketplace entry** for actively-developed
  internal plugins. Leaving it unset makes Claude Code use the git commit SHA as the
  version, so every push is automatically an update. If `version` is ever set in *both*
  places, `plugin.json` silently wins — set it in exactly one place.
- **Renaming/deleting a plugin**: never mutate `name` directly (it's a permanent install
  key). Add an entry to the `renames` map instead (`"old": "new"` or `"old": null` to
  delete) and treat `renames` as **append-only** — never edit past entries.
- **Templates are copied, never hand-rewritten** ("Salin, jangan tulis ulang dari nol").
  Both scaffolders use the same `copy_if_absent()` helper so re-running never clobbers
  edited files — follow this idempotent-copy pattern for any future scaffolding script.
- **No top-level `bin/` in a plugin** — rejected by Organization-managed distribution.
  Put executables under `scripts/` and reference them as
  `${CLAUDE_PLUGIN_ROOT}/scripts/<name>`.
- **Plugins are copied to a cache on install** — never reference files outside a plugin's
  own directory (e.g. `../shared-utils`); they won't be copied along.
- **Docs philosophy baked into the SOP skill/templates** (applies to any repo that installs
  this plugin, and to this repo's own docs): ADRs and CHANGELOG are append-only (never
  edit old entries — supersede instead); business-flow/glossary/runbook are living docs
  (edited in place, history via `git log -p`); only write down rationale/pitfalls/non-obvious
  conventions — anything recoverable from the code itself doesn't belong in docs.

## Important Files

| File | Role |
|---|---|
| `README.md` | Full operator manual: install flow, auto-install via settings.json, add-plugin procedure, versioning pitfalls, rename/delete via `renames`, private-repo auth caveats (`CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE`, `gh auth setup-git`), naming rules, `bin/` restriction. Read this in full before changing marketplace structure or release process. |
| `.claude-plugin/marketplace.json` | Marketplace identity (`qti-plugins`), owner, and the `plugins[]` registry (`name`, `source`, `description`, `category`, `tags`, `author`) plus `renames`. |
| `contoh-settings-repo-projek/.claude/settings.json` | Example consumer-side config: `extraKnownMarketplaces` + `enabledPlugins`. |
| `plugins/<name>/.claude-plugin/plugin.json` | Plugin manifest: `name`, `displayName`, `description`, `author`, `keywords`. |
| `plugins/sop-projek-baru/skills/sop-projek-baru/SKILL.md` | Docs SOP behavior spec: doc taxonomy, 4-scenario workflow (new project / mid-project decision / version bump / session close), "what's worth writing down" litmus test, `CLAUDE.md` size/pointer guidance. |
| `plugins/sop-projek-baru/skills/sop-projek-baru/scripts/scaffold.sh` | Idempotent docs scaffolder (`docs/adr`, `docs/domain`, `docs/runbook`, `CHANGELOG.md`). |
| `plugins/qa-automation/skills/qa-automation/SKILL.md` | QA SOP behavior spec: test-pyramid litmus test, anti-flaky conventions (role-based selectors, no `waitForTimeout`, page objects without assertions), bug→regression-test order, quarantine policy, and the Huly reporting procedure incl. status mapping table. |
| `plugins/qa-automation/skills/qa-automation/scripts/scaffold-playwright.sh` | Idempotent Playwright scaffolder (`playwright.config.ts`, `tests/e2e/{fixtures.ts,pages,specs}`, `.github/workflows/e2e.yml`, `docs/qa/checklist.md`). |
| `plugins/qa-automation/skills/qa-automation/scripts/huly-report.mjs` | Parses Playwright's JSON reporter into `hulyStatus`/title rows (`--json` for machine use). Maps `expected→passed`, `unexpected→failed`, `flaky→passed` + warning note, `skipped→untested`. |
| `plugins/*/skills/*/assets/` | Seed templates copied verbatim into consumer repos. Never referenced from outside their own plugin directory. |

## Runtime/Tooling Preferences

- **No language runtime, package manager, or lockfile in this repo.** Content is JSON
  manifests + Markdown + two Bash scaffolders (`#!/usr/bin/env bash`, `set -euo pipefail`)
  + one Node ESM script.
- The only required external tool is the **`claude` CLI** (Claude Code) — used for
  `plugin validate`, `plugin marketplace add/update`, `plugin install`.
- Scaffolders must stay dependency-free Bash (no jq/Python) since they run inside arbitrary
  consumer repos via `${CLAUDE_PLUGIN_ROOT}/scripts/...`. `huly-report.mjs` may assume Node
  only because it runs in a Playwright project, which already requires Node.
- Asset TypeScript (`plugins/qa-automation/.../assets/*.ts`) must typecheck under `strict`
  in the consumer project; it is never compiled here.

## Testing & QA

There is **no automated test suite, CI workflow, or lint config** in this repo. Quality
gate is manual, documented in `README.md`:

1. `claude plugin validate .` — schema-validates `.claude-plugin/marketplace.json` and
   every `plugin.json`, run from repo root. Expected output today: *passed with 2 warnings*
   (one `version: No version specified` per plugin) — those warnings are intentional, see
   the versioning rule above; do not "fix" them by adding a `version`.
2. `claude plugin marketplace add ./claude-plugins` (from the parent directory) — local
   install smoke test before pushing. Undo with `claude plugin marketplace remove qti-plugins`
   so the local directory source doesn't shadow the GitHub source later.

Scaffolders carry no test logic — only a pre-flight check that their own `assets/` dir
exists plus the `copy_if_absent` no-clobber guard. After changing a `SKILL.md`, script, or
asset, verify by hand in a scratch directory:

```bash
# docs SOP
bash .../scaffold.sh /tmp/demo && bash .../scaffold.sh /tmp/demo   # 2nd run must print "lewat … (sudah ada)"

# QA plugin — full loop
bash .../scaffold-playwright.sh /tmp/qa-demo
cd /tmp/qa-demo && npm i -D @playwright/test && npx playwright install chromium
E2E_BASE_URL=http://localhost:3000 npx playwright test
node .../huly-report.mjs test-results/results.json
```
