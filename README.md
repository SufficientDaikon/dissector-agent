# 🔬 Dissector

**A Claude Code multi-agent system that reverse-engineers any codebase into an agent-optimized knowledge base.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Multi--Agent_System-orange.svg)](https://code.claude.com/docs)

Point it at a repository and it produces a `{project}-dissection/` folder — a complete, machine-parseable map of the codebase (architecture, modules, APIs, conventions, patterns, tests, build system, dependencies) that another AI agent can load to understand the project without re-scanning it, extend it safely, rebuild it from scratch, or keep it maintained as the code evolves.

---

## Why agent-optimized output?

Traditional generated docs are written for humans. Dissector's output is written for **agents**:

- **Markdown + YAML frontmatter** — the format every agent runtime already navigates (the same convention as `llms.txt`, `AGENTS.md`, `CLAUDE.md`, `SKILL.md`), substantially cheaper in tokens than JSON or XML, and line-oriented so it survives chunked reads, greps cleanly, and git-diffs minimally.
- **Progressive disclosure** — a small `index.md` root (always cheap to load) links to focused per-domain and per-module files, each 200–600 lines. Agents load only what they need.
- **Greppable citations** — every factual claim carries an own-line token like `cite: src/parser/index.ts#L18-L31 symbol: parse`, so `rg 'src/parser/'` over the KB finds every claim about a file.
- **Deterministic and diffable** — sorted lists, stable path-derived IDs, volatile metadata confined to `manifest.yaml`. Regenerating from unchanged sources produces near-identical bytes.
- **Staleness-aware** — `manifest.yaml` records which source globs each KB file covers plus content hashes, so after a code change you can compute exactly which KB files are dirty and regenerate only those.

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

## Installation

**Zero-install (project-local):** clone this repo and start Claude Code inside it — the `.claude/` directory is picked up automatically and `/dissect` is available in that session.

**User-level install (available in every project):**

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

Progress is reported with phase banners (`[Phase 3-11/13] Parallel analysis...`). On a re-run against the same project, an existing dissection folder (identified by its `manifest.yaml` marker) is overwritten after a warning; a same-named folder *without* the marker is never touched.

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
├── modules/<module-id>.md  # one file per module: purpose, files, exports, gotchas
├── api/<module-id>.md      # public API per module: signatures + citations
└── guides/
    ├── extend.md           # recipes: add a feature/endpoint/test, conventions to follow
    └── rebuild.md          # reconstruction map: build order, extension points, fork strategy
```

**How agents consume it:** load `index.md`, follow links as needed; grep `cite:` tokens to jump into source; read `manifest.yaml` for coverage and staleness. To check whether a dissection is stale after code changes: intersect `git diff --name-only` with each entry's `covers` globs (or compare `source_hashes`) and regenerate only the dirty files.

Guarantees: never executes target code (static analysis only), redacts detected secrets (`[REDACTED]` + `secrets_redacted: true` in the manifest), never crashes on unreadable files (skips and logs them), and refuses to overwrite non-dissection folders.

## Configuration

**Models are not hard-coded.** No agent pins a `model:` — every specialist inherits your session's model. To change what runs the analysis:

- Set your session model (`/model` in Claude Code) — specialists follow it.
- Route all subagents to a specific model: set the `CLAUDE_CODE_SUBAGENT_MODEL` environment variable.
- Pin per-role models by adding a `model:` line to any agent's frontmatter (e.g. a cheaper model for `dissection-stack-auditor`, a stronger one for `dissection-synthesist`).

Reasoning `effort` per agent ships with task-shaped defaults (`low` for the mechanical stack audit, `high` for pattern analysis and synthesis) — also just frontmatter, edit freely.

Sampling adapts automatically to codebase size: under 500 source files every file is read; 500–2,000 everything is read with repetitive patterns summarized; over 2,000 a stratified sample (all entry points/configs/APIs/tests exhaustively, proportional sampling elsewhere) is used and disclosed in `index.md` and `manifest.yaml`.

## FAQ

**Why no persistent agent memory?** Claude Code subagents support a `memory:` field, but Dissector deliberately doesn't use it — dissections must be deterministic (same code in, same facts out), and memory from a previous run leaking into a new one would break that. Idempotency is handled by `manifest.yaml` instead.

**What is `manifest.yaml` for?** Three things: it marks the folder as a dissection (safe-overwrite check), records what was analyzed and how (counts, sampling tier, skipped files, redaction flag), and maps every KB file to the source globs and content hashes it was derived from (staleness detection).

**A specialist failed mid-run — now what?** The run continues; the result is marked partial (`status.complete: false` in the manifest, a completion checklist in `index.md`) and the summary tells you which specialist to re-run. Re-running `/dissect` regenerates the whole dissection.

**How do I update a dissection after the code changed?** Re-run `/dissect` (cheap for small/medium repos), or use the staleness data in `manifest.yaml` to identify dirty files and ask Claude to re-run just the owning specialist.

## License

MIT — see [LICENSE](LICENSE).
