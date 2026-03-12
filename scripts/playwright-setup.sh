#!/usr/bin/env bash
# playwright-setup.sh — Detect/install Playwright + Chromium, configure MCP, output environment
# Usage: playwright-setup.sh
# Output: "host" or "ddev" (the environment where Playwright is available)
# Exit 1 on failure
#
# Priority: host first (typically has modern Node), ddev only if Node >= 18 there.

set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"
MIN_NODE_MAJOR=18

log() { echo "[playwright-setup] $*" >&2; }

# Get major Node version; returns 0 if node is missing
node_major() {
  local v
  v=$("$@" --version 2>/dev/null) || { echo 0; return; }
  echo "${v#v}" | cut -d. -f1
}

# --- 1. Check host ---
check_host() {
  local maj
  maj=$(node_major node)
  (( maj >= MIN_NODE_MAJOR )) && npx playwright --version >/dev/null 2>&1
}

# --- 2. Check ddev ---
check_ddev() {
  ddev describe >/dev/null 2>&1 || return 1
  local maj
  maj=$(ddev exec node --version 2>/dev/null | tr -d 'v' | cut -d. -f1)
  (( maj >= MIN_NODE_MAJOR )) && ddev exec npx playwright --version >/dev/null 2>&1
}

# --- 3. Ensure Chromium is installed in a given environment ---
ensure_chromium() {
  local env="$1"
  if [[ "$env" == "host" ]]; then
    local pw_cache="$HOME/.cache/ms-playwright"
    if ! ls "$pw_cache"/chromium-* >/dev/null 2>&1; then
      log "Installing Chromium browser on host..."
      npx playwright install chromium >&2
    fi
  elif [[ "$env" == "ddev" ]]; then
    if ! ddev exec bash -c 'ls /root/.cache/ms-playwright/chromium-* 2>/dev/null' >/dev/null 2>&1; then
      log "Installing Chromium browser in ddev..."
      ddev exec npx playwright install chromium >&2
    fi
  fi
}

# --- 4. Install Playwright on host if nowhere available ---
install_host() {
  log "Playwright not found. Installing globally on host..."
  npm install -g playwright@^1 >&2
  npx playwright install chromium >&2
}

# --- 5. Ensure MCP server config in settings.json ---
ensure_mcp_config() {
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    cat > "$SETTINGS_FILE" << 'JSON'
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}
JSON
    log "Created $SETTINGS_FILE with Playwright MCP config"
    return
  fi

  # Check if playwright MCP is already configured
  if grep -q '"playwright"' "$SETTINGS_FILE" 2>/dev/null; then
    return
  fi

  # Insert mcpServers.playwright into existing settings
  if grep -q '"mcpServers"' "$SETTINGS_FILE" 2>/dev/null; then
    sed -i '/"mcpServers"[[:space:]]*:[[:space:]]*{/a\    "playwright": {\n      "command": "npx",\n      "args": ["@playwright/mcp@latest"]\n    },' "$SETTINGS_FILE"
  else
    sed -i '$s/}/,\n  "mcpServers": {\n    "playwright": {\n      "command": "npx",\n      "args": ["@playwright\/mcp@latest"]\n    }\n  }\n}/' "$SETTINGS_FILE"
  fi
  log "Added Playwright MCP server to $SETTINGS_FILE"
}

# --- Main ---
ENV=""

if check_host; then
  ENV="host"
  log "Playwright found on host (Node $(node --version))"
elif check_ddev; then
  ENV="ddev"
  log "Playwright found in ddev (Node $(ddev exec node --version 2>/dev/null))"
else
  # Host Node is modern enough but Playwright not installed — install it
  host_maj=$(node_major node)
  if (( host_maj >= MIN_NODE_MAJOR )); then
    install_host
    if check_host; then
      ENV="host"
    fi
  fi

  if [[ -z "$ENV" ]]; then
    log "ERROR: No environment with Node >= $MIN_NODE_MAJOR and Playwright available"
    log "Install Node >= $MIN_NODE_MAJOR on the host or in ddev, then retry."
    exit 1
  fi
fi

ensure_chromium "$ENV"
ensure_mcp_config

echo "$ENV"
