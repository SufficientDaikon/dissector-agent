#!/usr/bin/env bash
# install.sh — Dissector Agent Installer for macOS/Linux
# Run: chmod +x install.sh && ./install.sh

set -e

echo ""
echo "🔬 Installing Dissector Agent..."
echo ""

# Determine paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENTS_DIR="$HOME/.copilot/agents"
SOURCE_FILE="$SCRIPT_DIR/agents/dissector.agent.md"
DEST_FILE="$AGENTS_DIR/dissector.agent.md"

# Verify source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "❌ Error: Source file not found at $SOURCE_FILE"
    echo "   Make sure you're running this from the dissector-agent repository root."
    exit 1
fi

# Create the agents directory if it doesn't exist
if [ ! -d "$AGENTS_DIR" ]; then
    mkdir -p "$AGENTS_DIR"
    echo "✅ Created $AGENTS_DIR"
else
    echo "✅ Found existing $AGENTS_DIR"
fi

# Copy the agent file
cp "$SOURCE_FILE" "$DEST_FILE"
echo "✅ Copied dissector.agent.md to $AGENTS_DIR"

echo ""
echo "🎉 Installation complete!"
echo ""
echo "Installed files:"
echo "  $DEST_FILE"
echo ""
echo "To use: Open VS Code Copilot Chat and type:"
echo '  @dissector Dissect /path/to/your/codebase'
echo ""
