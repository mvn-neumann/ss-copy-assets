#!/usr/bin/env bash
# install.sh — Install ss-copy-assets skill and scripts to ~/.claude/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# Create target directories
mkdir -p "$CLAUDE_DIR/skills/ss-copy-assets"
mkdir -p "$CLAUDE_DIR/scripts"

# Copy skill files
cp "$SCRIPT_DIR/skills/ss-copy-assets.md" "$CLAUDE_DIR/skills/ss-copy-assets.md"
cp "$SCRIPT_DIR/skills/ss-copy-assets/SKILL.md" "$CLAUDE_DIR/skills/ss-copy-assets/SKILL.md"

# Copy scripts and make executable
cp "$SCRIPT_DIR/scripts/playwright-setup.sh" "$CLAUDE_DIR/scripts/playwright-setup.sh"
cp "$SCRIPT_DIR/scripts/playwright-capture.sh" "$CLAUDE_DIR/scripts/playwright-capture.sh"
cp "$SCRIPT_DIR/scripts/copy-images.sh" "$CLAUDE_DIR/scripts/copy-images.sh"
chmod +x "$CLAUDE_DIR/scripts/"*.sh

echo "ss-copy-assets installed successfully."
echo ""
echo "Files:"
echo "  ~/.claude/skills/ss-copy-assets.md"
echo "  ~/.claude/skills/ss-copy-assets/SKILL.md"
echo "  ~/.claude/scripts/playwright-setup.sh"
echo "  ~/.claude/scripts/playwright-capture.sh"
echo "  ~/.claude/scripts/copy-images.sh"
echo ""
echo "Usage: /ss-copy-assets https://www.example.com/"
