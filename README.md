# 🔬 Dissector Agent

**A Copilot CLI agent that reverse-engineers any codebase into comprehensive, organized documentation through 13 systematic analysis phases.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Copilot CLI](https://img.shields.io/badge/Copilot_CLI-Agent-purple.svg)](#prerequisites)
[![Model: claude-opus-4.6](https://img.shields.io/badge/Model-claude--opus--4.6-orange.svg)](#configuration)

---

## Hero Summary

The Dissector Agent is a **GitHub Copilot CLI custom agent** that takes a filesystem path to any codebase and autonomously produces a complete documentation folder covering architecture, design patterns, coding conventions, API references, testing patterns, security practices, build systems, dependencies, and actionable contribution/fork guides. It works with any programming language and produces **17+ interlinked markdown documents** — no human interaction required after invocation.

---

## Visual Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     YOU (Developer)                          │
│                                                             │
│   > @dissector Dissect C:\projects\my-app                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   DISSECTOR AGENT                            │
│                                                             │
│  Phase  1: Discovery ─────── Scan file tree, detect langs   │
│  Phase  2: Structure ─────── Map directories & modules      │
│  Phase  3: Tech Stack ────── Frameworks, tools, CI/CD       │
│  Phase  4: Conventions ───── Reverse-engineer style guide   │
│  Phase  5: Patterns ─────── Design patterns & idioms        │
│  Phase  6: APIs ──────────── Public interfaces & endpoints  │
│  Phase  7: Testing ──────── Test framework & patterns       │
│  Phase  8: Error Handling ── Error types & logging          │
│  Phase  9: Security/Perf ── Auth, caching, bottlenecks     │
│  Phase 10: Dependencies ─── Every dep with purpose          │
│  Phase 11: Build System ─── Build, CI/CD, deployment        │
│  Phase 12: Synthesis ────── Guides, glossary, examples      │
│  Phase 13: Output ────────── Write 17+ docs to folder       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              "{project-name} dissection" FOLDER              │
│                                                             │
│  README.md ──────────── Master index & project overview     │
│  glossary.md ────────── Domain-specific terms               │
│  tech-stack.md ──────── Languages, frameworks, tools        │
│  testing-patterns.md ── Test framework, fixtures, mocks     │
│  error-handling.md ──── Error types, logging, recovery      │
│  build-system.md ────── Build tools, CI/CD, deployment      │
│  dependencies.md ────── Every dependency categorized        │
│  security-patterns.md ─ Auth, validation, secrets mgmt      │
│  performance-patterns.md ─ Caching, lazy loading, pooling   │
│  architecture/ ──────── Architecture overview + module map  │
│  patterns/ ──────────── Design patterns with code citations │
│  conventions/ ────────── Naming, formatting, imports        │
│  api-reference/ ─────── Exports, endpoints, CLI commands    │
│  best-practices/ ────── Observed practices as rules         │
│  contribution-guide/ ── Dev setup, coding standards, PRs    │
│  fork-guide/ ────────── Module classification, extensions   │
│  examples/ ──────────── Code examples organized by concept  │
└─────────────────────────────────────────────────────────────┘
```

---

## What's Included

| File | Description |
|------|-------------|
| [`agents/dissector.agent.md`](agents/dissector.agent.md) | The agent profile — 1,790 lines of structured instructions covering 13 analysis phases, error handling, secret redaction, and output specifications |
| [`docs/index.html`](docs/index.html) | Self-contained HTML documentation website with dark/light mode, syntax highlighting, and copy-to-clipboard |
| [`install.ps1`](install.ps1) | One-click installer for Windows (PowerShell) |
| [`install.sh`](install.sh) | One-click installer for macOS/Linux (Bash) |
| [`README.md`](README.md) | This file — complete usage guide |
| [`LICENSE`](LICENSE) | MIT License |

---

## Prerequisites

Before using the Dissector agent, you need:

1. **GitHub Copilot CLI** — The `github-copilot-cli` extension for VS Code, or the standalone Copilot CLI tool
   - Install: [GitHub Copilot CLI docs](https://docs.github.com/en/copilot/github-copilot-in-the-cli)
   - Verify: Run `copilot --version` in your terminal

2. **VS Code with Copilot Chat** (recommended) — The agent works best in the VS Code Copilot Chat panel
   - Install the [GitHub Copilot](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot) extension
   - Install the [GitHub Copilot Chat](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot-chat) extension

3. **A Copilot subscription** — Individual, Business, or Enterprise tier
   - The agent uses the `claude-opus-4.6` model for maximum analysis quality

4. **A codebase to analyze** — Any directory containing source code files

---

## Installation

### Option A: One-Click Install (Recommended)

**Windows (PowerShell):**

```powershell
# Clone the repository
git clone https://github.com/SufficientDaikon/dissector-agent.git

# Run the installer
cd dissector-agent
.\install.ps1
```

**macOS / Linux (Bash):**

```bash
# Clone the repository
git clone https://github.com/SufficientDaikon/dissector-agent.git

# Run the installer
cd dissector-agent
chmod +x install.sh
./install.sh
```

**Expected output:**

```
🔬 Installing Dissector Agent...
✅ Created ~/.copilot/agents/
✅ Copied dissector.agent.md to ~/.copilot/agents/
🎉 Installation complete!

Installed files:
  ~/.copilot/agents/dissector.agent.md

To use: Open VS Code Copilot Chat and type:
  @dissector Dissect /path/to/your/codebase
```

### Option B: Manual Install

```powershell
# Create the agents directory if it doesn't exist
mkdir -p ~/.copilot/agents/

# Copy the agent file
cp agents/dissector.agent.md ~/.copilot/agents/dissector.agent.md
```

### Verify Installation

After installing, open VS Code and in the Copilot Chat panel type:

```
@dissector What can you do?
```

You should see the agent respond describing its 13-phase analysis capability.

---

## Quick Start

Three commands to get your first dissection:

```bash
# 1. Install the agent (if not already done)
git clone https://github.com/SufficientDaikon/dissector-agent.git && cd dissector-agent && ./install.sh

# 2. Open VS Code in any project
code /path/to/any/project

# 3. In Copilot Chat, run:
#    @dissector Dissect this codebase
```

That's it. The agent runs all 13 phases autonomously and produces a `"{project-name} dissection"` folder in your working directory.

---

## Detailed Usage

### Basic Dissection

Provide an absolute or relative path to any codebase:

```
@dissector Dissect C:\Users\dev\projects\my-app
```

```
@dissector Analyze /home/user/repos/express
```

```
@dissector Reverse-engineer this codebase: D:\work\api-server
```

Or if you're already in the project directory:

```
@dissector Dissect this codebase
```

### What Happens During a Dissection

The agent prints progress as it works through 13 phases:

```
[Phase 1/13] Discovery... (scanning file tree)
[Phase 1/13] Discovery complete — 342 source files in 3 languages (TypeScript 68%)
[Phase 2/13] Structure... (mapping directory architecture)
[Phase 3/13] Tech Stack... (identifying frameworks and tools)
...
[Phase 13/13] Output... (writing 18 documents to "my-app dissection")

✅ Dissection complete!

📂 Output: C:\Users\dev\projects\my-app dissection
📊 Files analyzed: 342 of 487 total
🗣️ Languages: TypeScript, JavaScript, Python
📝 Documents generated: 18
📐 Sampling: Exhaustive (all files analyzed)
⏱️ Phases completed: 13/13
```

### Understanding the Output

After a dissection, you'll find a folder named `"{project-name} dissection"` in your current directory. Here's how to navigate it:

| If you want to... | Read this file |
|--------------------|----------------|
| Understand the project's architecture | `architecture/README.md` |
| Learn the coding style before contributing | `conventions/README.md` |
| Set up a development environment | `contribution-guide/README.md` |
| Fork and customize the project | `fork-guide/README.md` |
| Understand every dependency | `dependencies.md` |
| Learn the testing patterns | `testing-patterns.md` |
| Find API endpoints or exports | `api-reference/README.md` |
| Review security practices | `security-patterns.md` |
| Look up domain terminology | `glossary.md` |

### Re-Running a Dissection

The agent is **idempotent**. If you run it again on the same codebase:

- If a previous `"{project-name} dissection"` folder exists with a `.dissection-metadata` file, the agent will **overwrite** it
- If a folder with that name exists but is NOT a previous dissection, the agent will **refuse to overwrite** and ask you to rename it

---

## Prompts & Examples

### 🟢 Getting Started

**Dissect a local project:**

> `@dissector Dissect C:\Users\dev\projects\my-express-api`

**Expected result:** A `"my-express-api dissection"` folder with 17+ markdown files covering architecture, patterns, conventions, APIs, testing, security, build system, and more.

---

**Dissect the current workspace:**

> `@dissector Analyze this codebase`

**Expected result:** The agent detects the current workspace root and produces a dissection folder in the working directory.

---

**Dissect a specific subdirectory:**

> `@dissector Reverse-engineer the backend: /home/user/monorepo/packages/api`

**Expected result:** The agent scopes its analysis to only the `packages/api` directory and produces an `"api dissection"` folder.

---

### 🔵 Common Workflows

**Onboard to a new team's codebase:**

> `@dissector Dissect /home/dev/company/main-service`

Then open `contribution-guide/README.md` first — it contains dev setup, coding standards, and how to add features.

---

**Evaluate a library before adopting it:**

> `@dissector Dissect ~/repos/some-open-source-lib`

Then read `tech-stack.md` and `architecture/README.md` to understand its dependencies and design.

---

**Prepare for a code review:**

> `@dissector Dissect D:\work\feature-branch-checkout`

Then check `conventions/README.md` and `patterns/README.md` to understand the project's established patterns.

---

**Document a legacy codebase:**

> `@dissector Dissect C:\legacy\old-java-monolith`

The agent handles any language and produces structured documentation even for projects with no existing docs.

---

**Analyze a monorepo:**

> `@dissector Dissect /home/user/my-monorepo`

The agent detects monorepo structures (Lerna, pnpm workspaces, Cargo workspaces, etc.) and documents sub-projects as separate modules.

---

### 🟣 Advanced Usage

**Dissect after cloning an unfamiliar open-source project:**

```bash
git clone https://github.com/expressjs/express.git
cd express
# In Copilot Chat:
# @dissector Dissect this codebase
```

**Expected result:** A complete `"express dissection"` folder documenting Express.js internals — middleware pipeline, router, request/response extensions, and more.

---

**Chain dissections for comparison:**

Dissect two codebases separately, then compare their architecture documents manually:

```
@dissector Dissect ~/repos/project-a
# (wait for completion)
@dissector Dissect ~/repos/project-b
# Then compare: project-a dissection/architecture/ vs project-b dissection/architecture/
```

---

**Use dissection output as context for other agents:**

After dissecting a codebase, reference the output in other Copilot conversations:

```
@workspace Based on the architecture documented in "my-app dissection/architecture/README.md",
help me add a new microservice that follows the same patterns.
```

---

### 🔴 Troubleshooting

**Agent says "Path does not exist":**

> Make sure you're providing an absolute path or the project is in your current workspace. Try:
> `@dissector Dissect C:\exact\path\to\project`

---

**Dissection seems incomplete (says PARTIAL):**

> The agent hit its context window limit. This happens with very large codebases (5000+ files). The output folder will have a `[PARTIAL]` marker in the README showing which phases completed. Simply run the dissector again — it's idempotent and will overwrite the partial output.

---

## Configuration

### Model Selection

The agent is configured to use `claude-opus-4.6` for maximum analysis quality. To change the model, edit `dissector.agent.md` and modify the `model` field in the YAML frontmatter:

```yaml
---
model: claude-opus-4.6  # Change to claude-sonnet-4 for faster analysis
---
```

**Model tradeoffs:**

| Model | Speed | Quality | Best For |
|-------|-------|---------|----------|
| `claude-opus-4.6` | Slower | Highest | Thorough analysis, large codebases |
| `claude-sonnet-4` | Faster | High | Quick dissections, smaller codebases |

### Sampling Tiers

The agent automatically selects a sampling strategy based on codebase size:

| Source Files | Strategy | Coverage |
|-------------|----------|----------|
| < 500 | Exhaustive | 100% of files |
| 500–2,000 | Full + Summarize | 100% analyzed, repetitive patterns summarized |
| > 2,000 | Stratified Sampling | 100% of structural files + 15% sample of each module |

No configuration needed — this is automatic.

---

## File Reference

| Path | Purpose |
|------|---------|
| `agents/dissector.agent.md` | The complete agent profile (1,790 lines) defining all 13 analysis phases, error handling, output format specs, and the code citation format |
| `docs/index.html` | Self-contained documentation website — open in any browser, no server needed |
| `install.ps1` | Windows installer — copies agent file to `~/.copilot/agents/` |
| `install.sh` | macOS/Linux installer — copies agent file to `~/.copilot/agents/` |
| `LICENSE` | MIT License |
| `README.md` | This documentation |

---

## Architecture

The Dissector Agent is a single `.agent.md` file that runs inside GitHub Copilot CLI. It uses Copilot's tool system to interact with the filesystem:

```
┌───────────────────────────────────────────────┐
│               Copilot CLI Runtime              │
│                                               │
│  ┌──────────────────────────────────────────┐ │
│  │         dissector.agent.md               │ │
│  │                                          │ │
│  │  YAML Frontmatter (metadata, tools)      │ │
│  │           │                              │ │
│  │  System Prompt (1,750+ lines)            │ │
│  │    ├── Core Identity                     │ │
│  │    ├── Input Validation                  │ │
│  │    ├── 13 Analysis Phases                │ │
│  │    ├── Output Document Specs             │ │
│  │    ├── Error Handling (26 edge cases)    │ │
│  │    ├── Secret Redaction Protocol         │ │
│  │    └── Tool Usage Guide                  │ │
│  └──────────┬───────────────────────────────┘ │
│             │ Uses tools:                     │
│  ┌──────────▼───────────────────────────────┐ │
│  │  glob ─── Find files by pattern          │ │
│  │  grep ─── Search file contents           │ │
│  │  read ─── Read file with line numbers    │ │
│  │  create ─ Write output documents         │ │
│  │  powershell ─ File system operations     │ │
│  │  task ─── Delegate to sub-agents         │ │
│  └──────────────────────────────────────────┘ │
└───────────────────────────────────────────────┘
```

### How It Works

1. **You invoke the agent** with a codebase path
2. **The agent validates** the path exists, is a directory, and is not empty
3. **13 phases execute sequentially** — each phase reads code files and builds analysis data
4. **Phase 13 writes output** — all documents are written to a `"{project-name} dissection"` folder
5. **Every code excerpt is cited** with file path and line numbers back to the original source

### Key Design Decisions

- **Static analysis only** — The agent never executes, compiles, or runs your code
- **Autonomous** — Once started, it runs all 13 phases without asking questions
- **Resilient** — Unreadable files, encoding errors, and binary files are skipped gracefully
- **Honest** — Documents what IS, not what should be; notes discrepancies
- **Idempotent** — Safe to re-run; detects and overwrites previous dissections

---

## Troubleshooting

### "Agent not found" when typing `@dissector`

**Cause:** The agent file is not in the correct directory.

**Fix:** Verify the file exists:

```powershell
# Windows
Test-Path "$env:USERPROFILE\.copilot\agents\dissector.agent.md"

# macOS/Linux
test -f ~/.copilot/agents/dissector.agent.md && echo "Found" || echo "Not found"
```

If not found, re-run the installer.

### Dissection takes a very long time

**Cause:** Large codebases (2000+ files) require extensive analysis.

**Fix:** The agent automatically uses stratified sampling for large codebases. If you need faster results, edit the agent to use `claude-sonnet-4` instead of `claude-opus-4.6`.

### "Context window exhaustion" / Partial output

**Cause:** Very large codebases may exhaust the LLM's context window.

**Fix:** The agent automatically executes its Context Exhaustion Protocol — writing all completed documents and marking the output as `[PARTIAL]`. You can re-run the agent on the same codebase to get a fresh, complete analysis.

### Output folder "already exists" error

**Cause:** A folder with the expected output name exists but was NOT created by the dissector.

**Fix:** Rename or move the conflicting folder, then re-run the agent.

### Binary files or images appear in analysis

**Cause:** Unexpected file extensions.

**Fix:** The agent automatically excludes known binary formats. If you see issues, the file may have an unusual extension. The agent logs skipped files in `.dissection-metadata`.

---

## Contributing

### Modifying the Agent

The agent is a single markdown file. To modify its behavior:

1. Edit `~/.copilot/agents/dissector.agent.md`
2. Changes take effect immediately — no build step required
3. Test by running `@dissector Dissect /path/to/small/test/project`

### Adding a New Analysis Phase

1. Add the phase definition in Section 6 (between the existing phases or after Phase 12)
2. Update the phase count in all progress messages
3. Add the output document specification in Section 7
4. Update the output folder structure in Phase 13
5. Update the README template in Phase 12

### Reporting Issues

Open an issue at [github.com/SufficientDaikon/dissector-agent/issues](https://github.com/SufficientDaikon/dissector-agent/issues) with:

- The codebase size (approximate file count)
- The error message or unexpected behavior
- Your Copilot CLI version (`copilot --version`)

---

## License

[MIT](LICENSE) — use it, modify it, share it.
