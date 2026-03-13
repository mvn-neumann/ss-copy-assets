#!/usr/bin/env bash
# install.sh — Install ss-copy-assets skill, scripts, and dependencies to ~/.claude/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
LOCAL_LIB="$CLAUDE_DIR/lib"

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

# Install Playwright npm module if not already available
install_playwright() {
  # Check global
  local g
  g="$(npm root -g 2>/dev/null)" || true
  if [[ -n "$g" && -d "$g/playwright" ]]; then
    echo "Playwright already installed globally."
    return 0
  fi
  # Check local
  if [[ -d "$LOCAL_LIB/node_modules/playwright" ]]; then
    echo "Playwright already installed in $LOCAL_LIB."
    return 0
  fi
  # Install locally (no sudo needed)
  echo "Installing Playwright to $LOCAL_LIB ..."
  mkdir -p "$LOCAL_LIB"
  (cd "$LOCAL_LIB" && npm init -y --silent >/dev/null 2>&1 && npm install playwright@^1)
  echo "Playwright installed."
}

# Check Node.js version
NODE_MAJ=$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)
if [[ -z "$NODE_MAJ" ]] || (( NODE_MAJ < 18 )); then
  echo "WARNING: Node.js >= 18 required (found: $(node --version 2>/dev/null || echo 'none'))."
  echo "Install Node.js >= 18, then re-run this script."
else
  install_playwright
fi

echo ""
echo "ss-copy-assets installed successfully."
echo ""
echo "Files:"
echo "  ~/.claude/skills/ss-copy-assets.md"
echo "  ~/.claude/skills/ss-copy-assets/SKILL.md"
echo "  ~/.claude/scripts/playwright-setup.sh"
echo "  ~/.claude/scripts/playwright-capture.sh"
echo "  ~/.claude/scripts/copy-images.sh"
echo "  ~/.claude/lib/node_modules/playwright  (npm module)"
echo ""
echo "Next steps:"
echo "  Run: ~/.claude/scripts/playwright-setup.sh"
echo "  This detects/installs Chromium and configures the MCP server."
echo ""
echo "Usage: /ss-copy-assets https://www.example.com/"
