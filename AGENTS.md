# Repository Guidelines

## Project Overview

Internal Claude Code **plugin marketplace** for QTI Engineering (`qti-plugins`). It is not
an application — there is no runtime service, no build artifact, no compiled output. The
repo's job is to declare a marketplace manifest and host plugin sources that teams install
into their own projects via the `claude` CLI. All prose (README, SKILL.md, templates) is
written in Indonesian for an internal audience.

The one shipped plugin, `sop-projek-baru` ("new-project SOP"), teaches Claude Code to
proactively maintain architecture/documentation hygiene in *consumer* repos: ADRs, living
domain docs (business-flow, glossary), CHANGELOG, and a lean `CLAUDE.md`.

## Architecture & Data Flow

```
qti-plugins (this repo)                 consumer repo (any team's project)
├─ .claude-plugin/marketplace.json      ├─ .claude/settings.json
│   lists plugins[] {name, source}      │   extraKnownMarketplaces.qti-plugins
└─ plugins/sop-projek-baru/             │   enabledPlugins["sop-projek-baru@qti-plugins"]
   ├─ .claude-plugin/plugin.json        └─ (auto-registers marketplace on trust,
   └─ skills/sop-projek-baru/                no install prompt)
      ├─ SKILL.md   (agent playbook, frontmatter = auto-trigger matcher)
      ├─ scripts/scaffold.sh (idempotent doc-tree generator)
      └─ assets/*.md (templates copy-pasted into the consumer repo)
```

Flow: a maintainer edits a plugin under `plugins/<name>/`, registers it in
`marketplace.json`, validates, and pushes. Downstream users either run
`claude plugin install …` manually, or get it automatically via a committed
`.claude/settings.json` (see `contoh-settings-repo-projek/`). Once installed, the skill's
long, scenario-dense `description:` frontmatter causes Claude to **auto-activate** the SOP
skill from conversational context (new repo, architecture decision, "why did we pick X")
— the explicit slash command `/sop-projek-baru:sop-projek-baru` is only a manual fallback.
When active, the skill instructs the agent to run `scripts/scaffold.sh` in the *consumer*
repo, which copies templates from its own `assets/` into `docs/adr`, `docs/domain`,
`docs/runbook`, and `CHANGELOG.md` — never overwriting existing files.

## Key Directories

Repo root layout (the structure Claude Code's plugin loader expects):

```
.claude-plugin/marketplace.json
contoh-settings-repo-projek/.claude/settings.json
plugins/sop-projek-baru/
  .claude-plugin/plugin.json
  skills/sop-projek-baru/{SKILL.md,scripts/scaffold.sh,assets/*.md}
```

| Path | Purpose |
|---|---|
| `.claude-plugin/marketplace.json` | Marketplace manifest. **Must** live under `.claude-plugin/` — a copy at repo root is not discovered (`claude plugin validate .` fails with "No manifest found in directory"). |
| `contoh-settings-repo-projek/.claude/settings.json` | Copy-paste **example** for a consuming project's own `.claude/settings.json`. Not this repo's own settings. |
| `plugins/<plugin-name>/` | One directory per plugin. Must contain `.claude-plugin/plugin.json` plus any of `skills/`, `commands/`, `agents/`, `hooks/`. |
| `plugins/sop-projek-baru/skills/sop-projek-baru/` | The only skill in the repo: `SKILL.md` (playbook), `scripts/scaffold.sh` (doc scaffolder), `assets/` (5 Markdown templates). |

## Development Commands

There is no build/test/lint tooling — the "tooling" is the `claude` CLI itself:

```bash
# Validate marketplace + plugin manifests (run from repo root)
claude plugin validate .

# Install this marketplace locally for a smoke test before pushing
claude plugin marketplace add ./claude-plugins

# End-user flow (from a consumer repo)
claude plugin marketplace add ORG-KAMU/claude-plugins
claude plugin install sop-projek-baru@qti-plugins
claude plugin marketplace update   # refresh cached marketplace after a push

# Manually run the SOP scaffolder against a target project (invoked by the skill itself)
bash plugins/sop-projek-baru/skills/sop-projek-baru/scripts/scaffold.sh [target-dir]
```

If an install summary says `Run /reload-plugins to activate.`, run that command next.

## Code Conventions & Common Patterns

- **Naming triad**: plugin directory name == `plugin.json` `name` == skill directory name
  == `SKILL.md` frontmatter `name` (all `sop-projek-baru`, kebab-case). This is what makes
  the slash command `/sop-projek-baru:<skill-name>` resolve.
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
  `scaffold.sh` uses a `copy_if_absent()` helper so re-running it never clobbers edited
  docs — follow this idempotent-copy pattern for any future scaffolding script.
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
| `plugins/sop-projek-baru/.claude-plugin/plugin.json` | Plugin manifest: `name`, `displayName`, `description`, `author`, `keywords`. |
| `plugins/sop-projek-baru/skills/sop-projek-baru/SKILL.md` | The actual behavior spec the agent follows: doc taxonomy, 4-scenario workflow (new project / mid-project decision / version bump / session close), "what's worth writing down" litmus test, `CLAUDE.md` size/pointer guidance, `.claude/rules/` path-scoped rule example. |
| `plugins/sop-projek-baru/skills/sop-projek-baru/scripts/scaffold.sh` | Idempotent bash scaffolder; only executable code in the repo. |
| `plugins/sop-projek-baru/skills/sop-projek-baru/assets/*.md` | Seed templates: `adr-template.md`, `business-flow.md`, `glossary.md`, `CHANGELOG.md`, `CLAUDE.md.template`. |

## Runtime/Tooling Preferences

- **No language runtime, no package manager, no lockfile.** The repo is pure JSON
  manifests + Markdown + one POSIX shell script (`#!/usr/bin/env bash`, `set -euo pipefail`).
- The only required external tool is the **`claude` CLI** (Claude Code) — used for
  `plugin validate`, `plugin marketplace add/update`, `plugin install`.
- `scaffold.sh` must remain plain, dependency-free Bash (no Node/Python) since it's
  executed inside arbitrary consumer repos via `${CLAUDE_PLUGIN_ROOT}/...`.

## Testing & QA

There is **no automated test suite, CI workflow, or lint config** in this repo. Quality
gate is manual, two steps, documented in `README.md`:

1. `claude plugin validate .` — schema-validates `.claude-plugin/marketplace.json` and
   every `plugin.json`, run from repo root. Expected output today: *passed with 1 warning*
   (`plugins[0] plugin.json → version: No version specified`) — that warning is
   intentional, see the versioning rule above; do not "fix" it by adding a `version`.
2. `claude plugin marketplace add ./claude-plugins` (from the parent directory) — local
   install smoke test before pushing. Undo with `claude plugin marketplace remove qti-plugins`
   so the local directory source doesn't shadow the GitHub source later.

`scaffold.sh` has no test/lint logic of its own; its only safety check is a pre-flight
existence check on its own `assets/` directory and the `copy_if_absent` no-clobber guard.
When changing `SKILL.md` or `scaffold.sh`, verify by hand: run `claude plugin validate .`,
then run `scaffold.sh` against a scratch directory and confirm the expected `docs/`
tree, `CHANGELOG.md`, and re-run idempotency (no overwrites, correct "sudah ada" skip
messages).
