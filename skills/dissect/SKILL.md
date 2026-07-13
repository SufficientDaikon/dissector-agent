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

**Shell portability.** Every Bash command in Stage 0 and Stage 4 is POSIX-bash — the Claude Code Bash tool provides bash on Windows too (via the bundled git-bash), so bash syntax is safe on all platforms. Avoid GNU-only flags. Where a common tool differs across platforms (e.g. `sha256sum` is absent on stock macOS), use the portable fallback form shown below.

**Scale envelope.** Dissector is tested on small and medium repositories (under ~2,000 source files). Tier-3 stratified sampling engages above 2,000 source files. Very large monorepos should be dissected per-package — point `/dissect` at a package directory rather than the monorepo root. Stage 0 counts files and, above the 2,000-source-file threshold, asks the user to confirm or narrow scope.

## Stage 0 — Preflight (yourself, no subagents)

1. **Parse the path** from the invocation. Expand `~`; accept `/` or `\` and normalize to `/`; quote paths with spaces in all commands. If no path was given and the user plainly means the current project, use the current working directory; otherwise ask for a path. Store it as the shell variable `TARGET_PATH` (never name it `PATH` — that clobbers the executable search path and breaks every later command).
2. **Validate** (Bash, in order, stop at first failure — print the exact message and HALT without creating anything):
   - `[ -e "$TARGET_PATH" ]` fails → `❌ Error: Path '{path}' does not exist. Please provide a valid filesystem path to a codebase directory.`
   - `[ -d "$TARGET_PATH" ]` fails → `❌ Error: '{path}' is a file, not a directory. Please provide the root directory of the codebase.`
   - `find "$TARGET_PATH" -type f | head -1` empty → `❌ Error: '{path}' is an empty directory. No files found to analyze.`
   - Store the absolute normalized path (resolved via `realpath` / `cd … && pwd`) as `CODEBASE_PATH`.
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
4. **Scale check** (Bash): count source files (post-exclusion; a `find` that prunes the standard exclude dirs and `*-dissection` is fine) and print a scale line:
   ```
   📊 {SOURCE_FILES} source files (~{TOTAL_FILES} total). Rough token estimate: ~{SOURCE_FILES × 400} tokens of source at Tier 1.
   ```
   (The 400-tokens-per-file figure is a coarse average; it is only a rough order-of-magnitude estimate, state it as such.) If `SOURCE_FILES > 2000`, do NOT proceed automatically — print:
   ```
   ⚠️ This codebase has {SOURCE_FILES} source files, above Dissector's tested envelope (~2,000). Tier-3 stratified sampling will engage, so the KB will be a sample, not exhaustive. For a monorepo, consider pointing /dissect at a single package directory instead. Reply "continue" to dissect the whole tree at Tier 3, or give me a subdirectory path.
   ```
   and wait for the user's decision before continuing.
5. **Git commit sample** (Bash): if `CODEBASE_PATH` is a git work tree (`git -C "$CODEBASE_PATH" rev-parse --is-inside-work-tree` succeeds), capture `git -C "$CODEBASE_PATH" log --oneline -20` subjects into `GIT_COMMIT_SAMPLE` (a short newline-joined list). The synthesist has no Bash, so it cannot sample git itself — you pass this in. If not a git tree, `GIT_COMMIT_SAMPLE` is empty.
6. **Idempotency & safe overwrite**: `OUTPUT_FOLDER = "{PROJECT_NAME}-dissection"` in the CWD; `OUTPUT_PATH` = its absolute path (`"$PWD/$OUTPUT_FOLDER"`).
   - **Folder does not exist** → proceed to step 7.
   - **Folder exists WITHOUT `manifest.yaml`** → print `❌ Error: A folder named "{OUTPUT_FOLDER}" already exists but is not a previous dissection (no manifest.yaml marker). Cannot overwrite.` and `💡 Suggestion: Rename the existing folder or run from a different working directory.` → HALT.
   - **Folder exists WITH `manifest.yaml`** → run the checks below IN ORDER, before any deletion; ALL must pass. The concurrency-lock check comes FIRST, because the overwrite gate ends by deleting the folder (and the `.dissect-lock` inside it) — inspect the lock while it still exists.
     1. **Concurrency lock**: if `OUTPUT_PATH/.dissect-lock` exists and its timestamp is younger than 2 hours (`find "$OUTPUT_PATH/.dissect-lock" -mmin -120` non-empty, or compare the stored epoch to `date +%s`), another dissection is in progress — refuse: `❌ Error: Another dissection of "{PROJECT_NAME}" appears to be running (lock at {OUTPUT_PATH}/.dissect-lock, < 2h old). Wait for it to finish or delete the lock if it is stale.` → HALT.
     2. **Generator marker**: parse `OUTPUT_PATH/manifest.yaml` and require `generator.name: dissector`. If absent/different → refuse: `❌ Error: "{OUTPUT_FOLDER}" contains a manifest.yaml not written by Dissector (generator.name is not "dissector"). Refusing to delete it.` → HALT. (A stub manifest written in step 7 of a prior interrupted run also carries `generator.name: dissector` with `status.complete: false` — that IS a resumable/overwritable previous dissection, so it passes this gate.)
     3. **Provenance match**: read `generated_from.path` from that manifest. If it is present and does NOT resolve to the same path as `CODEBASE_PATH`, refuse: `❌ Error: "{OUTPUT_FOLDER}" is a dissection of a DIFFERENT codebase ({other_path}), not {CODEBASE_PATH}. Refusing to overwrite it — rename it or run elsewhere.` → HALT. (A stub with no `generated_from.path` yet is allowed.)
     4. **Realpath assertion**: resolve BOTH sides before comparing — assert `realpath "$OUTPUT_PATH"` equals `"$(realpath "$PWD")/$OUTPUT_FOLDER"` (i.e. `dirname` of the resolved output equals the resolved current directory and the leaf name is exactly `OUTPUT_FOLDER`). Resolving both sides keeps a symlinked *ancestor* of `$PWD` (macOS `/tmp`→`/private/tmp`, a symlinked `$HOME`) from false-refusing a legit re-run. If it still resolves outside the current directory, refuse: `❌ Error: "{OUTPUT_FOLDER}" does not resolve to a folder directly inside the current directory. Refusing to delete {resolved}.` → HALT.
   - Only when all four pass: print `⚠️ Previous dissection found at "{OUTPUT_PATH}". Overwriting...`, then `rm -rf "$OUTPUT_PATH"` and proceed.
7. **Create folder, stub manifest, and lock**:
   - `mkdir -p "$OUTPUT_PATH/modules" "$OUTPUT_PATH/api" "$OUTPUT_PATH/guides"` so parallel specialists never race on directories.
   - Immediately write a **stub `OUTPUT_PATH/manifest.yaml`** so an interrupted run is recognizable and overwritable next time (Stage 4 overwrites it with the full manifest):
     ```yaml
     schema_version: "1.0"
     spec: {okf: "0.1"}
     generator: {name: dissector, version: 2.3.0}
     generated_from:
       path: <CODEBASE_PATH>
     status: {complete: false, phases_completed: 0}
     ```
   - Write the lock: `date +%s > "$OUTPUT_PATH/.dissect-lock"`.
8. **Output self-exclusion in a git work tree**: if `CODEBASE_PATH` is a git work tree AND `OUTPUT_PATH` is inside it (the user ran `/dissect .` and the CWD is the repo), append the output folder to `.git/info/exclude` so the generated KB never pollutes `git status`: `printf '%s\n' "$OUTPUT_FOLDER/" >> "$CODEBASE_PATH/.git/info/exclude"` (only if not already present). This is local-only and reversible; never edit the tracked `.gitignore`.

## Stage 1 — Scout

Print `[Phase 1-2/13] Discovery & Structure — scanning file tree and mapping modules...`

Spawn `dissection-scout` with a prompt containing exactly:
```
CODEBASE_PATH: <path>
OUTPUT_PATH: <path>
PROJECT_NAME: <name>
EXCLUDE_FROM_ANALYSIS: <OUTPUT_PATH> (the dissection output folder — never read or count files under it)
Run your full Phase 1-2 analysis, write your KB files, and return the Recon Brief plus manifest.
```
Validate the returned manifest (see **Manifest validation** below) and keep its returned `recon_brief` and `manifest` verbatim — you will paste the brief into every later prompt.

**Scout failure handling**: if the scout errors or returns no/invalid manifest, retry it ONCE. If it fails again, **HALT the entire run** with: `❌ Error: The scout failed to produce a Recon Brief after a retry. Nothing downstream can run without it. Please re-run /dissect; if it persists, the codebase structure may be unreadable.` Remove the lock (`rm -f "$OUTPUT_PATH/.dissect-lock"`) before halting. The Recon Brief is a hard dependency for every other stage — there is no partial path around it.

## Stage 2 — Parallel fan-out

Print `[Phase 3-11/13] Parallel analysis — stack, style, interfaces, quality...`

Spawn ALL FOUR in a SINGLE message (four Agent calls at once): `dissection-stack-auditor`, `dissection-style-analyst`, `dissection-interface-documenter`, `dissection-quality-auditor`. Each prompt:
```
CODEBASE_PATH: <path>
OUTPUT_PATH: <path>
PROJECT_NAME: <name>
EXCLUDE_FROM_ANALYSIS: <OUTPUT_PATH> (the dissection output folder — never read or count files under it)
<the full recon_brief YAML block>
Run your phases, write your KB files, and return your manifest.
```
Collect the four manifests. Validate each (see below). If a specialist fails (error, no manifest, or a manifest still malformed after the bounce-back), retry it once; if it fails again, record it as partial and continue.

## Stage 3 — Synthesist

Print `[Phase 12/13] Synthesis — guides, glossary, index...`

Spawn `dissection-synthesist` with a prompt containing CODEBASE_PATH / OUTPUT_PATH / PROJECT_NAME, the `EXCLUDE_FROM_ANALYSIS` line, the recon_brief, ALL FIVE manifests (scout + four), the `GIT_COMMIT_SAMPLE` block captured in Stage 0, and a note of which files are missing/partial so index.md carries the completion checklist. Include:
```
GIT_COMMIT_SAMPLE: |
  <the up-to-20 commit subject lines, or "none — not a git work tree">
```

**Synthesist failure handling**: validate its manifest. If it errors or returns an invalid manifest, retry ONCE. If it fails again, do NOT halt — mark the run partial (`status.complete: false`, add the synthesist's files to `partial_files`), and in the completion summary tell the user: `⚠️ Synthesis (index, glossary, guides) failed. The per-domain KB files are present; re-run /dissect to regenerate the cross-cutting files.` The KB is still usable without the synthesized index.

## Manifest validation (applies to every specialist manifest)

Before using any returned manifest, validate it has all required keys: `agent`, `phases`, `status`, `files_written`, `key_findings`. `files_written` must be a list of `{path, covers}`; `status` must be `complete` or `partial`. If a manifest is malformed (missing keys, wrong shape), **re-spawn that specialist ONCE** with a bounce-back note quoting exactly what was wrong, e.g.:
```
Your previous manifest was rejected: <the specific problem, e.g. "missing required key 'files_written'" or "status was 'done', must be 'complete' or 'partial'">. Re-emit ONLY the manifest block per dissection-standards §7, correctly structured.
```
If the re-spawn is still malformed, treat the specialist as failed (Stage 2 partial protocol; Stage 1/3 per their halt/partial rules above).

## Stage 4 — Finalize (yourself)

Print `[Phase 13/13] Output — manifest, verification, summary...`

1. **Write `OUTPUT_PATH/manifest.yaml`** — aggregate from the manifests, overwriting the Stage 0 stub:
```yaml
schema_version: "1.0"
spec: {okf: "0.1"}                    # Open Knowledge Format v0.1-compatible bundle (superset: adds cite: source tokens + this manifest)
generator: {name: dissector, version: 2.3.0}
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
  secrets_redacted: true|false      # OR of all manifests AND the Stage-4 backstop below
  skipped_files: []                  # union of all manifests
citations:                           # filled in step 4
  total: 0
  verified: 0
  broken: []
entries:                             # sorted by id; one per KB file from files_written
  - id: <path minus .md>
    covers: [<globs from the owning manifest>]
    source_hashes: {}                # filled in step 2
```
2. **Source hashes** (one Bash pass): for every distinct source file matched by the `covers` globs — or, simpler and acceptable, every source file the scout counted — compute a portable SHA-256 and take the first 8 hex chars. Use the portable fallback (`sha256sum` is absent on stock macOS):
   ```bash
   hash_file() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -c1-8; else shasum -a 256 "$1" | cut -c1-8; fi; }
   ```
   Fill `source_hashes` per entry (files matching that entry's `covers`). If the codebase is very large (>2,000 files), hash only entry-point/config/API files plus per-entry sampled files and note `source_hashes_partial: true`.
3. **Output-side secret backstop** (one Bash grep pass over the generated KB — a deterministic safety net independent of what the specialists redacted): grep every `OUTPUT_PATH/**/*.md` for the modern token patterns, each **anchored** to a token-shaped value (word boundary + charset + length) so ordinary identifiers like `flask-cors`, `task-runner`, `npm_config_*`, or `disk-cache` never false-positive and corrupt the KB (same provider set as dissection-standards §5, expressed here as anchored regexes since this grep has no variable-name context to key off): `\bsk-(ant-)?[A-Za-z0-9_-]{20,}`, `\bgh[pos]_[A-Za-z0-9]{36}`, `\bgithub_pat_[A-Za-z0-9_]{22,}`, `\bxox[bps]-[A-Za-z0-9-]{10,}`, `\bAIza[0-9A-Za-z_-]{35}`, `\bnpm_[A-Za-z0-9]{36}`, `\bglpat-[A-Za-z0-9_-]{20,}`, `\bpypi-AgEIcHlwaS5vcmc[A-Za-z0-9_-]{20,}`, `\bdop_v1_[a-f0-9]{64}`, `\bshp(at|ss)_[a-fA-F0-9]{32}`, plus `AKIA[A-Z0-9]{16}`, `-----BEGIN [A-Z ]*PRIVATE KEY-----`, and JWT `eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*`. Any hit that is not an obvious placeholder → replace the matched value with `[REDACTED]` in that KB file (sed in place), set `status.secrets_redacted: true`, and report each redaction location in the summary. This catches secrets a specialist echoed into a snippet.
4. **Citation verification pass** (deterministic, no LLM): scan every `cite:` token across all `OUTPUT_PATH/**/*.md`. Tokens appear in **two accepted forms** (standards §4): own-line `cite: <relpath>#L<start>-L<end> symbol: <name>`, and a quoted YAML field `cite: "<relpath>#L<start>-L<end>"` inside a fenced record. Your parser MUST handle both, or it will falsely fail correct cites:
   - **Strip surrounding quotes** from the captured `<relpath>` (and any trailing `"`/`,`/`}` from the YAML form) before `test -e`. A relpath beginning with `"` is a parse bug on your side, not a broken cite.
   - **Symbol match is last-component and substring.** A `symbol:` may be a bare name (`send`) or dotted (`HTTPAdapter.send`); the source line at the `def`/`class` keyword contains only the bare name. So compare against the **trailing `.`-delimited component** (`send`) and treat the check as passing if that token appears anywhere in the cited range. Never fail a cite solely because the dotted class prefix is absent from the source line.
   
   For each token: (a) `test -e "$CODEBASE_PATH/<relpath>"` — file exists; (b) `<end>` ≤ the file's line count (`wc -l`); (c) if a `symbol:` is given, `sed -n "<start>,<end>p"` of the file contains the symbol's trailing component. A bash loop with `sed`/`grep` does all three. Record `citations.total` (tokens seen), `citations.verified` (tokens passing all checks), and `citations.broken` (list of `{cite, reason}` for genuine failures only). Broken cites are REPORTED, not silently dropped — leave the KB text as the specialist wrote it (the specialists self-verify per standards §4; this pass is the backstop and the trust metric). If your first pass reports an implausibly high broken rate (say >25%), suspect your own parser (quote-stripping or symbol-matching) before trusting the number.
5. **Verify structure**: every `files_written` path exists; extract relative markdown links from each KB file and `test -e` them from the file's directory; index.md < 200 lines. Fix trivial breaks yourself (a broken link target → remove or correct the link); anything structural goes to `status.partial_files`.
6. **Remove the lock**: `rm -f "$OUTPUT_PATH/.dissect-lock"`.
7. **Print the completion summary**:
```
✅ Dissection complete!

📂 Output: {OUTPUT_PATH}
📊 Files analyzed: {SOURCE_FILES} of {TOTAL_FILES} total
🗣️ Languages: {LANGUAGE_LIST}
📝 KB files generated: {COUNT}
📐 Sampling: tier {N}
🔗 Citations: {VERIFIED}/{TOTAL} verified{, N broken (see manifest.yaml) if any}
🔒 Secrets: {redacted N values | none detected}
⏱️ Phases completed: {N}/13
🤖 Agents: point any agent at {OUTPUT_PATH}/index.md to load the codebase map.
```
   Then tell the user how to wire the KB into their tools: the synthesist wrote `{OUTPUT_PATH}/AGENTS.md` as a cross-tool entry point. Offer the exact one-line snippet they can add to their repo's `CLAUDE.md` / `AGENTS.md` (do NOT write into the analyzed repo yourself):
```
💡 To make agents use this automatically, add one line to your repo's CLAUDE.md or AGENTS.md:
   > See {OUTPUT_FOLDER}/index.md for the dissected codebase map (architecture, APIs, conventions).
   Or copy {OUTPUT_FOLDER}/AGENTS.md into your repo root as a cross-tool entry point.
```

## Partial-run protocol

Never abort the whole run for one failed specialist (the sole exception is a scout that fails twice — see Stage 1). Mark what's missing (`status.complete: false`, `phases_completed` < 13, `partial_files` listing missing KB files), make sure the synthesist added the completion checklist to index.md, and tell the user which specialist to re-run. Always remove the lock before returning, even on a partial or halted run. Determinism: same codebase state in, same structure/facts out — phrasing may vary, facts and citations may not.
