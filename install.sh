#!/usr/bin/env bash
# install.sh — Dissector Installer for macOS/Linux (Claude Code)
# Run: chmod +x install.sh && ./install.sh

set -e

echo ""
echo "🔬 Installing Dissector (Claude Code multi-agent system)..."
echo ""

# Determine paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
AGENTS_SRC="$SCRIPT_DIR/.claude/agents"
SKILLS_SRC="$SCRIPT_DIR/.claude/skills"
COMMANDS_SRC="$SCRIPT_DIR/.claude/commands"

# Verify source files exist
if [ ! -d "$AGENTS_SRC" ] || [ ! -d "$SKILLS_SRC" ] || [ ! -d "$COMMANDS_SRC" ]; then
    echo "❌ Error: .claude/ sources not found under $SCRIPT_DIR"
    echo "   Make sure you're running this from the dissector-agent repository root."
    exit 1
fi

# Warn (don't fail) if the Claude Code CLI isn't on PATH
if ! command -v claude >/dev/null 2>&1; then
    echo "⚠️  Claude Code CLI ('claude') not found on PATH."
    echo "   Install it first: https://code.claude.com/docs — the files will still be copied."
    echo ""
fi

mkdir -p "$CLAUDE_DIR/agents" "$CLAUDE_DIR/skills" "$CLAUDE_DIR/commands"

# Copy agents
for f in "$AGENTS_SRC"/*.md; do
    cp "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
    echo "✅ Installed agent   $(basename "$f")"
done

# Copy skills (each skill is a directory; copy it whole so bundled reference files survive)
for d in "$SKILLS_SRC"/*/; do
    name="$(basename "$d")"
    rm -rf "$CLAUDE_DIR/skills/$name"
    cp -R "$d" "$CLAUDE_DIR/skills/$name"
    echo "✅ Installed skill   $name"
done

# Copy commands
for f in "$COMMANDS_SRC"/*.md; do
    cp "$f" "$CLAUDE_DIR/commands/$(basename "$f")"
    echo "✅ Installed command /$(basename "$f" .md)"
done

echo ""
echo "🎉 Installation complete!"
echo ""
echo "💡 Preferred install is now the Claude Code plugin (versioned, auto-update,"
echo "   ships the write-guard hook). From any Claude Code session:"
echo "     /plugin marketplace add SufficientDaikon/dissector-agent"
echo "     /plugin install dissector@dissector-marketplace"
echo "   This script-copy install remains a fallback for offline/no-plugin setups."
echo ""
echo "To use, open any Claude Code session and run:"
echo "  /dissect /path/to/codebase"
echo ""
echo "Or launch a dedicated session:"
echo "  claude --agent dissector"
echo ""
echo "To uninstall, remove:"
echo "  $CLAUDE_DIR/agents/dissector.md and $CLAUDE_DIR/agents/dissection-*.md"
echo "  $CLAUDE_DIR/skills/dissect and $CLAUDE_DIR/skills/dissection-standards"
echo "  $CLAUDE_DIR/commands/dissect.md"
echo ""
