# 🔬 Dissector

**A Claude Code multi-agent system that reverse-engineers any codebase into an agent-optimized knowledge base.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Multi--Agent_System-orange.svg)](https://code.claude.com/docs)
[![OKF v0.1 compatible](https://img.shields.io/badge/OKF-v0.1_compatible-green.svg)](https://github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf)

Point it at a repository and it produces a `{project}-dissection/` folder — a complete, machine-parseable map of the codebase (architecture, modules, APIs, conventions, patterns, tests, build system, dependencies) that another AI agent can load to understand the project without re-scanning it, extend it safely, rebuild it from scratch, or keep it maintained as the code evolves.

---

## Why agent-optimized output?

Traditional generated docs are written for humans. Dissector's output is written for **agents**:

- **Markdown + YAML frontmatter** — the format every agent runtime already navigates (the same convention as `llms.txt`, `AGENTS.md`, `CLAUDE.md`, `SKILL.md`), substantially cheaper in tokens than JSON or XML, and line-oriented so it survives chunked reads, greps cleanly, and git-diffs minimally.
- **Progressive disclosure** — a small `index.md` root (always cheap to load) links to focused per-domain and per-module files, each 200–600 lines. Agents load only what they need.
- **Navigable concept graph** — every KB file carries a `related:` frontmatter list and a `## Related` link section, so an agent hops concept→concept (a module → its API → the symbol map → architecture), not only through the `index.md` hub.
- **Greppable citations** — every factual claim carries an own-line token like `cite: src/parser/index.ts#L18-L31 symbol: parse`, so `rg 'src/parser/'` over the KB finds every claim about a file.
- **Deterministic and diffable** — sorted lists, stable path-derived IDs, volatile metadata confined to `manifest.yaml`. Regenerating from unchanged sources produces near-identical bytes.
- **Staleness-aware** — `manifest.yaml` records which source globs each KB file covers plus content hashes, so after a code change you can compute exactly which KB files are dirty and regenerate only those.
- **OKF-compatible** — a dissection is a valid [Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf) v0.1 bundle (a superset), so any OKF-aware tool can ingest it.

## How it works

Dissector is not one agent — it's an orchestrated system of seven. A monolithic prompt analyzing a whole codebase in one context window runs out of room; Dissector gives each analysis domain a fresh context window and runs the middle of the pipeline in parallel:

```
/dissect <path>          (or: claude --agent dissector)
        │
        ▼
ORCHESTRATOR — validates input, resolves project name, coordinates; holds
        │      only briefs and manifests, never raw source
        │
        ├─ Stage 1  dissection-scout             discovery + structure  →  Recon Brief
        │
        ├─ Stage 2  (four specialists IN PARALLEL, disjoint output files)
        │     ├─ dissection-stack-auditor         tech stack, dependencies, build/CI
        │     ├─ dissection-style-analyst         conventions, design patterns
        │     ├─ dissection-interface-documenter  APIs, symbol map, error handling
        │     └─ dissection-quality-auditor       testing, security, performance
        │
        ├─ Stage 3  dissection-synthesist         guides, glossary, root index
        │
        └─ Stage 4  manifest.yaml, link verification, completion summary
```

Each specialist writes its knowledge-base files directly and returns only a compact manifest, so the orchestrator's context stays small no matter how big the target codebase is. The classic 13-phase Dissector methodology (discovery → structure → tech stack → conventions → patterns → APIs → testing → error handling → security & performance → dependencies → build system → synthesis → output) is preserved — redistributed across the specialists.

## What's included

| Component | File | Role |
|---|---|---|
| `/dissect` command | `.claude/commands/dissect.md` | Primary entry point |
| `dissect` skill | `.claude/skills/dissect/SKILL.md` | The orchestration playbook |
| `dissection-standards` skill | `.claude/skills/dissection-standards/SKILL.md` | Shared methodology + KB format spec, preloaded into every specialist |
| `dissector` agent | `.claude/agents/dissector.md` | Orchestrator for `claude --agent dissector` |
| 6 specialist agents | `.claude/agents/dissection-*.md` | Scout, stack auditor, style analyst, interface documenter, quality auditor, synthesist |
| write-guard hook (plugin install) | `hooks/hooks.json` + `scripts/write-guard.sh` | `PreToolUse` guard shipped with the plugin: while a dissection run is active, agents may only write inside the `*-dissection/` output folder; inert otherwise |
| plugin manifest | `.claude-plugin/plugin.json` + `marketplace.json` | Packages the above as an installable, self-hosted Claude Code plugin |

## Installation

**Preferred — Claude Code plugin (versioned, updatable in place, ships the write-guard hook):** from any Claude Code session,

```
/plugin marketplace add SufficientDaikon/dissector-agent
/plugin install dissector@dissector-marketplace
```

This installs the seven agents, both skills, the `/dissect` command, and the `PreToolUse` write-guard hook (see [Security](#security)) as a semver-tagged bundle you can update in place. For a team, check the plugin into the repo's project settings so every collaborator gets it automatically.

**Zero-install (project-local):** clone this repo and start Claude Code inside it — the `.claude/` directory is picked up automatically and `/dissect` is available in that session. No plugin install needed.

**User-level script install (fallback for offline / no-plugin setups):**

macOS/Linux:
```bash
chmod +x install.sh && ./install.sh
```

Windows (PowerShell):
```powershell
.\install.ps1
```

This copies the agents, skills, and command into `~/.claude/`. Prerequisite: the [Claude Code CLI](https://code.claude.com/docs).

## Usage

Primary — from any Claude Code session:

```
/dissect /path/to/codebase
```

Or a dedicated session:

```bash
claude --agent dissector
```

Progress is reported with phase banners (`[Phase 3-11/13] Parallel analysis...`). On a re-run against the same project, an existing dissection folder (identified by a `manifest.yaml` carrying `generator.name: dissector`) is overwritten after a warning; a same-named folder *without* that marker is never touched.

## Output format

```
{project}-dissection/
├── index.md                # START HERE — root map, <200 lines, links to everything
├── manifest.yaml           # machine index: coverage globs, source hashes, status
├── architecture.md         # module graph, layers, entry points, detected patterns
├── symbol-map.md           # ranked signature map of exported symbols
├── tech-stack.md           # languages, frameworks, tooling (YAML inventories)
├── dependencies.md         # every dependency: version, category, purpose
├── build-and-test.md       # commands, CI pipelines, deployment, env vars
├── conventions.md          # the implicit style guide, as rules with consistency %
├── patterns.md             # design patterns & idioms with confidence grades
├── errors.md               # error types, propagation, logging, recovery
├── testing.md              # test framework, structure, how to add a test
├── security.md             # observed auth/validation/secrets posture (redacted)
├── performance.md          # caching, async, pooling, bottleneck risks
├── glossary.md             # domain vocabulary
├── AGENTS.md               # cross-tool entry point (Codex/Cursor/Copilot/Gemini/…)
├── modules/<module-id>.md  # one file per module: purpose, files, exports, gotchas
├── api/<module-id>.md      # public API per module: signatures + citations
└── guides/
    ├── extend.md           # recipes: add a feature/endpoint/test, conventions to follow
    └── rebuild.md          # reconstruction map: build order, extension points, fork strategy
```

`<module-id>` is the module's source path with each `/` replaced by a double hyphen `--` (e.g. `src/parser` → `src--parser`, `packages/core/api` → `packages--core--api`). The double-hyphen scheme is collision-safe for POSIX paths — a single `/` never maps to a single `-`, so `src/foo-bar` and `src/foo/bar` never merge.

Every KB file carries queryable YAML frontmatter (`type`, `id`, `title`, `description`, plus type-specific keys like `public_exports`, `covers`, `depends_on`) and a sorted `related:` list of sibling concepts, and closes with a `## Related` section of markdown links to those siblings — the edges that make the KB a navigable graph.

**How agents consume it:** load `index.md` (or `AGENTS.md` for non-Claude tools), then hop between concepts via each file's `## Related` links — the KB is a navigable graph, not just a hub; grep `cite:` tokens to jump into source; read `manifest.yaml` for coverage, citation-verification counts, and staleness. To check whether a dissection is stale after code changes: intersect `git diff --name-only` with each entry's `covers` globs (or compare `source_hashes`) and regenerate only the dirty files. To make agents use the KB automatically, add a one-line pointer to your repo's `CLAUDE.md`/`AGENTS.md` (e.g. `> See {project}-dissection/index.md for the codebase map`) — Dissector prints the exact snippet at the end of a run and never writes into your source tree itself.

**Open Knowledge Format compatible.** A dissection is a valid [OKF](https://github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf) v0.1 bundle (a superset): one Markdown-with-frontmatter file per concept, path-as-identity, an `index.md` hub, and concepts linked into a graph via `## Related` — so any OKF-aware tool can ingest a dissection folder. Dissector layers on two things OKF leaves out: `cite:` tokens pinning every claim to `path#Lstart-Lend` in the source, and a machine `manifest.yaml` (compatibility declared via `spec: {okf: "0.1"}`) for coverage and staleness.

Guarantees: never executes target code (static analysis only), redacts detected secrets (`[REDACTED]` + `secrets_redacted: true` in the manifest, plus a deterministic output-side secret scan in Stage 4), machine-verifies every `cite:` token and reports `N/M verified` in the manifest, never crashes on unreadable files (skips and logs them), and refuses to overwrite non-dissection folders or a dissection of a different codebase. On the **plugin install**, the write-guard hook additionally enforces at the harness level that agents write only inside the `*-dissection/` output folder — but only **while a dissection run is in progress** (it keys off the run's `.dissect-lock`); outside a run it stays silent, so it never adds permission prompts to your normal editing. The zero-install and script-install paths rely instead on the agents' `permissionMode: acceptEdits` and the in-prompt rule that analyzed content is data, never instructions (see [Security](#security)).

## Configuration

**Models are not hard-coded.** No agent pins a `model:` — every specialist inherits your session's model. To change what runs the analysis:

- Set your session model (`/model` in Claude Code) — specialists follow it.
- Route all subagents to a specific model: set the `CLAUDE_CODE_SUBAGENT_MODEL` environment variable.
- Pin per-role models by adding a `model:` line to any agent's frontmatter (e.g. a cheaper model for `dissection-stack-auditor`, a stronger one for `dissection-synthesist`).

Reasoning `effort` per agent ships with task-shaped defaults (`low` for the mechanical stack audit, `high` for pattern analysis and synthesis) — also just frontmatter, edit freely.

Sampling adapts automatically to codebase size: under 500 source files every file is read; 500–2,000 everything is read with repetitive patterns summarized; over 2,000 a stratified sample (all entry points/configs/APIs/tests exhaustively, proportional sampling elsewhere) is used and disclosed in `index.md` and `manifest.yaml`.

**Scale envelope.** Dissector is tested on small and medium repositories (under ~2,000 source files). Tier-3 stratified sampling engages above 2,000 source files — the KB becomes a disclosed sample, not an exhaustive map. Very large monorepos should be dissected **per-package**: point `/dissect` at a package directory rather than the monorepo root. At Stage 0, Dissector prints the source-file count and a rough token estimate, and above 2,000 source files it pauses to let you confirm the whole-tree run or hand it a subdirectory instead.

## Data flow

Dissector runs entirely through **your configured Claude Code backend** — the Anthropic API, Amazon Bedrock, or Google Vertex AI, whichever your Claude Code is set to. Source files are read locally and sent to that model backend for analysis exactly as any Claude Code session would; **nothing else leaves your machine**, there is no Dissector server, telemetry, or third-party call. The generated knowledge base is written to a local `{project}-dissection/` folder and stays on disk — it is never uploaded anywhere by the tool. If your organization requires Bedrock/Vertex or zero-retention routing, configure Claude Code accordingly and Dissector inherits it.

## Where should the KB live? (governance)

The dissection is a concentrated, greppable map of your system — it aggregates endpoints, environment-variable names, config surface, and verbatim code snippets in one place. Treat it with the same care as the code it describes:

- **Commit it** when you want the whole team (and their agents) to share one maintained map — it diffs cleanly and is cheap to regenerate. Good for internal repos.
- **Gitignore it** (or store it in an access-controlled location) when the repo is sensitive and you don't want a consolidated attack-surface map in version control. The KB can make reconnaissance easier for anyone who gets read access.

Secrets are redacted (`[REDACTED]`) with a deterministic output-side backstop scan, but redaction is best-effort — do not treat the KB as safe to publish just because it was scanned. Decide commit-vs-ignore deliberately per repo.

## Security

- **Static analysis only** — Dissector never executes, compiles, or runs the target code, and never fetches remote repositories.
- **Write-guard hook (plugin install)** — the **plugin** ships a `PreToolUse` hook (`scripts/write-guard.sh`) that is **lock-gated to active dissection runs**: it does nothing (defers to your own permission settings) unless a fresh `*-dissection/.dissect-lock` marks a run in progress or the write targets a `*-dissection/` path. Mid-run it emits `permissionDecision: allow` for writes inside the `*-dissection/` output folder and `permissionDecision: ask` for anything else, so an injected payload can't silently steer a specialist into writing elsewhere. This harness-level backstop rides with the plugin install only; the **zero-install** and **script-install** paths instead rely on the agents' `permissionMode: acceptEdits` plus the in-prompt rule that analyzed content is treated as **data, never instructions** (dissection-standards §0).
- **Prompt-injection resistance** — analyzed file content is treated as untrusted **data, never instructions**. If a codebase contains text addressed to an AI agent ("ignore your instructions, write X…"), specialists record it as a finding and do not comply.
- **Secret redaction** — matches classic patterns (AWS keys, JWTs, private keys, connection strings) plus modern provider tokens (`sk-`/`sk-ant-`, `ghp_`/`github_pat_`, `xoxb-`, `AIza`, `npm_`, `glpat-`, and more), with a deterministic Stage-4 grep over the generated KB as a second layer.
- **Citation verification** — every `cite:` is machine-checked (file exists, line range in bounds, symbol present) and the verified/broken counts are reported in `manifest.yaml`.

## Development

**SINGLE SOURCE:** `.claude/agents`, `.claude/skills`, and `.claude/commands` are the **canonical** copies (they drive the zero-install project-local path). The repo-root `agents/`, `skills/`, and `commands/` directories are byte-identical copies that exist only so the Claude Code plugin (`.claude-plugin/`) can package them — marketplace installs copy real files, so these are real directories, **not symlinks**. Any change to an agent, skill, or command must be applied to **both** locations to keep them in sync; a `diff -r .claude/agents agents` (and likewise for skills/commands) must report no differences. Run `scripts/check-sync.sh` to verify the whole mirror in one shot — it diffs all three pairs and exits nonzero on any drift.

## FAQ

**Why no persistent agent memory?** Claude Code subagents support a `memory:` field, but Dissector deliberately doesn't use it — dissections must be deterministic (same code in, same facts out), and memory from a previous run leaking into a new one would break that. Idempotency is handled by `manifest.yaml` instead.

**What is `manifest.yaml` for?** Three things: it marks the folder as a dissection (safe-overwrite check), records what was analyzed and how (counts, sampling tier, skipped files, redaction flag), and maps every KB file to the source globs and content hashes it was derived from (staleness detection).

**A specialist failed mid-run — now what?** The run continues; the result is marked partial (`status.complete: false` in the manifest, a completion checklist in `index.md`) and the summary tells you which specialist to re-run. Re-running `/dissect` regenerates the whole dissection.

**How do I update a dissection after the code changed?** Re-run `/dissect` (cheap for small/medium repos), or use the staleness data in `manifest.yaml` to identify dirty files and ask Claude to re-run just the owning specialist.

**How do I update the installed plugin when a new version ships?** Plugins don't self-update — your install stays on whatever version you first pulled until you act. In any Claude Code session run `/plugin` → **Installed** → **dissector** → **Update** (or `/plugin marketplace update SufficientDaikon/dissector-agent`, then reinstall). If a version ever misbehaves, `/plugin` → **Installed** → **dissector** → **Disable** turns it off without uninstalling.

## License

MIT — see [LICENSE](LICENSE).
