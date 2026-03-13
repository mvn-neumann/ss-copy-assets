#!/usr/bin/env bash
# playwright-setup.sh — Detect/install Playwright + Chromium, configure MCP, output environment
# Usage: playwright-setup.sh
# Output: "host" or "ddev" (the environment where Playwright is available)
# Exit 1 on failure
#
# Priority: host first (typically has modern Node), ddev only if Node >= 18 there.

set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"
LOCAL_LIB="$HOME/.claude/lib"
MIN_NODE_MAJOR=18

log() { echo "[playwright-setup] $*" >&2; }

# Get major Node version; returns 0 if node is missing
node_major() {
  local v
  v=$("$@" --version 2>/dev/null) || { echo 0; return; }
  echo "${v#v}" | cut -d. -f1
}

# Resolve the node_modules directory containing playwright.
# Checks: 1) local lib  2) global npm root
resolve_playwright_node_path() {
  if [[ -d "$LOCAL_LIB/node_modules/playwright" ]]; then
    echo "$LOCAL_LIB/node_modules"
    return
  fi
  local g
  g="$(npm root -g 2>/dev/null)" || true
  if [[ -n "$g" && -d "$g/playwright" ]]; then
    echo "$g"
    return
  fi
  return 1
}

# --- 1. Check host ---
check_host() {
  local maj
  maj=$(node_major node)
  (( maj >= MIN_NODE_MAJOR )) || return 1
  resolve_playwright_node_path >/dev/null 2>&1
}

# --- 2. Check ddev ---
check_ddev() {
  ddev describe >/dev/null 2>&1 || return 1
  local maj
  maj=$(ddev exec node --version 2>/dev/null | tr -d 'v' | cut -d. -f1)
  (( maj >= MIN_NODE_MAJOR )) && ddev exec npx playwright --version >/dev/null 2>&1
}

# --- 3. Ensure Chromium is installed and can launch ---
ensure_chromium() {
  local env="$1"
  if [[ "$env" == "host" ]]; then
    local pw_cache="$HOME/.cache/ms-playwright"
    local np
    np=$(resolve_playwright_node_path)
    if ! ls "$pw_cache"/chromium-* >/dev/null 2>&1; then
      log "Installing Chromium browser on host..."
      NODE_PATH="$np" npx playwright install chromium >&2
    fi
    # Verify Chromium can actually launch (system deps may be missing)
    if ! NODE_PATH="$np" node -e "
      const { chromium } = require('playwright');
      chromium.launch({ headless: true }).then(b => { b.close(); process.exit(0); }).catch(() => process.exit(1));
    " 2>/dev/null; then
      log "Chromium cannot launch on host (missing system libraries)."
      log "Attempting: npx playwright install-deps chromium"
      NODE_PATH="$np" npx playwright install-deps chromium >&2 2>/dev/null || true
      # Re-check after install-deps
      if ! NODE_PATH="$np" node -e "
        const { chromium } = require('playwright');
        chromium.launch({ headless: true }).then(b => { b.close(); process.exit(0); }).catch(() => process.exit(1));
      " 2>/dev/null; then
        log "WARN: Host Chromium still broken. Falling back to ddev."
        return 1
      fi
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
  # Try global install first, fall back to local ~/.claude/lib/
  if npm install -g playwright@^1 >&2 2>/dev/null; then
    log "Installed Playwright globally"
  else
    log "Global install failed (permissions). Installing to $LOCAL_LIB ..."
    mkdir -p "$LOCAL_LIB"
    (cd "$LOCAL_LIB" && npm init -y --silent >/dev/null 2>&1 && npm install playwright@^1 >&2)
    log "Installed Playwright to $LOCAL_LIB"
  fi
  local np
  np=$(resolve_playwright_node_path) || { log "ERROR: Playwright install failed"; return 1; }
  NODE_PATH="$np" npx playwright install chromium >&2
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

  # Final fallback: try ddev
  if [[ -z "$ENV" ]] && check_ddev; then
    ENV="ddev"
    log "Falling back to ddev (Node $(ddev exec node --version 2>/dev/null))"
  fi

  if [[ -z "$ENV" ]]; then
    log "ERROR: No environment with Node >= $MIN_NODE_MAJOR and Playwright available"
    log "Install Node >= $MIN_NODE_MAJOR on the host or in ddev, then retry."
    exit 1
  fi
fi

# Ensure Chromium works; fall back to ddev if host Chromium is broken
if [[ "$ENV" == "host" ]]; then
  if ! ensure_chromium "host"; then
    if check_ddev; then
      ENV="ddev"
      ensure_chromium "ddev"
    else
      log "ERROR: Chromium cannot launch on host and ddev is not available."
      log "Install system dependencies: sudo npx playwright install-deps chromium"
      exit 1
    fi
  fi
else
  ensure_chromium "$ENV"
fi

ensure_mcp_config

echo "$ENV"
