---
name: dissect
description: Reverse-engineer a codebase into an agent-optimized knowledge base
  (a "{project}-dissection" folder) by orchestrating Dissector specialist
  subagents. Use when the user says "dissect", "reverse-engineer this codebase",
  "map this codebase", "document this codebase for agents", or runs
  /dissect <path>. Must run in the main session — it spawns subagents.
---

# Dissect — Orchestration Playbook

You are orchestrating a codebase dissection. You coordinate; you do not analyze source code yourself beyond preflight. Never paste raw source into your own context — only briefs and manifests. You are a static-analysis system: never execute, compile, or run the target code; no CVE scanning; no quality grading; no refactoring advice; no fetching remote repositories.

The output is an **agent-optimized knowledge base**: a `{PROJECT_NAME}-dissection/` folder of Markdown+YAML files that is a complete, parseable map of the codebase (see the dissection-standards skill for the file format the specialists follow).

If the Agent tool is unavailable in your session (you were spawned as a subagent), stop and tell the user to run `/dissect <path>` from their main session — do not attempt a single-context dissection.

## Stage 0 — Preflight (yourself, no subagents)

1. **Parse the path** from the invocation. Expand `~`; accept `/` or `\` and normalize to `/`; quote paths with spaces in all commands. If no path was given and the user plainly means the current project, use the current working directory; otherwise ask for a path.
2. **Validate** (Bash, in order, stop at first failure — print the exact message and HALT without creating anything):
   - `[ -e "$PATH" ]` fails → `❌ Error: Path '{path}' does not exist. Please provide a valid filesystem path to a codebase directory.`
   - `[ -d "$PATH" ]` fails → `❌ Error: '{path}' is a file, not a directory. Please provide the root directory of the codebase.`
   - `find "$PATH" -type f | head -1` empty → `❌ Error: '{path}' is an empty directory. No files found to analyze.`
   - Store the absolute normalized path as `CODEBASE_PATH`.
3. **Resolve `PROJECT_NAME`** — first match wins:
   1. `package.json` → `"name"`
   2. `Cargo.toml` → `[package] name`
   3. `pyproject.toml` → `[project]` or `[tool.poetry]` name
   4. `go.mod` → last segment of the `module` path
   5. `*.sln` filename (minus `.sln`)
   6. `composer.json` → `"name"` (part after `/` if scoped)
   7. `setup.py` / `setup.cfg` → `name`
   8. Fallback: leaf directory name of `CODEBASE_PATH`

   Sanitize: trim; replace `< > : " | ? *` and `/` with `-`; strip a leading `@scope-` if it makes the name unwieldy; empty → `unknown-project`. If multiple manifests exist, use the first per precedence and record the conflict for the synthesist. If the output path would exceed 260 chars, truncate the name to fit.
4. **Idempotency**: `OUTPUT_FOLDER = "{PROJECT_NAME}-dissection"` in the CWD; `OUTPUT_PATH` = its absolute path.
   - Exists with `manifest.yaml` inside → print `⚠️ Previous dissection found at "{OUTPUT_PATH}". Overwriting...`, `rm -rf` it, proceed.
   - Exists WITHOUT `manifest.yaml` → print `❌ Error: A folder named "{OUTPUT_FOLDER}" already exists but is not a previous dissection (no manifest.yaml marker). Cannot overwrite.` and `💡 Suggestion: Rename the existing folder or run from a different working directory.` → HALT.
5. `mkdir -p "$OUTPUT_PATH/modules" "$OUTPUT_PATH/api" "$OUTPUT_PATH/guides"` so parallel specialists never race on directories.

## Stage 1 — Scout

Print `[Phase 1-2/13] Discovery & Structure — scanning file tree and mapping modules...`

Spawn `dissection-scout` with a prompt containing exactly:
```
CODEBASE_PATH: <path>
OUTPUT_PATH: <path>
PROJECT_NAME: <name>
Run your full Phase 1-2 analysis, write your KB files, and return the Recon Brief plus manifest.
```
Keep its returned `recon_brief` and `manifest` verbatim — you will paste the brief into every later prompt.

## Stage 2 — Parallel fan-out

Print `[Phase 3-11/13] Parallel analysis — stack, style, interfaces, quality...`

Spawn ALL FOUR in a SINGLE message (four Agent calls at once): `dissection-stack-auditor`, `dissection-style-analyst`, `dissection-interface-documenter`, `dissection-quality-auditor`. Each prompt:
```
CODEBASE_PATH: <path>
OUTPUT_PATH: <path>
PROJECT_NAME: <name>
<the full recon_brief YAML block>
Run your phases, write your KB files, and return your manifest.
```
Collect the four manifests. If a specialist fails (error or no manifest), retry it once; if it fails again, record it as partial and continue.

## Stage 3 — Synthesist

Print `[Phase 12/13] Synthesis — guides, glossary, index...`

Spawn `dissection-synthesist` with CODEBASE_PATH / OUTPUT_PATH / PROJECT_NAME, the recon_brief, and ALL FIVE manifests (scout + four). Tell it which files are missing/partial so index.md carries the completion checklist.

## Stage 4 — Finalize (yourself)

Print `[Phase 13/13] Output — manifest, verification, summary...`

1. **Write `OUTPUT_PATH/manifest.yaml`** — aggregate from the manifests:
```yaml
schema_version: "1.0"
generator: {name: dissector, version: 2.0.0}
generated_from:
  path: <CODEBASE_PATH>
  commit: <git -C CODEBASE_PATH rev-parse HEAD, or null>
  date: <ISO 8601 now>
project:
  name: <PROJECT_NAME>
  primary_languages: [...]
  counts: {total: N, source: N, test: N, config: N}
  sampling_tier: 1|2|3
status:
  complete: true|false
  phases_completed: <N of 13>
  partial_files: []
  secrets_redacted: true|false      # OR of all manifests
  skipped_files: []                  # union of all manifests
entries:                             # sorted by id; one per KB file from files_written
  - id: <path minus .md>
    covers: [<globs from the owning manifest>]
    source_hashes: {}                # filled in step 2
```
2. **Source hashes** (one Bash pass): for every distinct source file matched by the `covers` globs — or, simpler and acceptable, every source file the scout counted — compute `sha256sum | cut -c1-8` and fill `source_hashes` per entry (files matching that entry's `covers`). If the codebase is very large (>2,000 files), hash only entry-point/config/API files plus per-entry sampled files and note `source_hashes_partial: true`.
3. **Verify**: every `files_written` path exists; extract relative markdown links from each KB file and `test -e` them from the file's directory; index.md < 200 lines. Fix trivial breaks yourself (a missing link target = ask the synthesist? No — remove or correct the link); anything structural goes to `status.partial_files`.
4. **Print the completion summary**:
```
✅ Dissection complete!

📂 Output: {OUTPUT_PATH}
📊 Files analyzed: {SOURCE_FILES} of {TOTAL_FILES} total
🗣️ Languages: {LANGUAGE_LIST}
📝 KB files generated: {COUNT}
📐 Sampling: tier {N}
⏱️ Phases completed: {N}/13
🤖 Agents: point any agent at {OUTPUT_PATH}/index.md to load the codebase map.
```

## Partial-run protocol

Never abort the whole run for one failed specialist. Mark what's missing (`status.complete: false`, `phases_completed` < 13, `partial_files` listing missing KB files), make sure the synthesist added the completion checklist to index.md, and tell the user which specialist to re-run. Determinism: same codebase state in, same structure/facts out — phrasing may vary, facts and citations may not.
