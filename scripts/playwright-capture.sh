#!/usr/bin/env bash
# playwright-capture.sh — Capture network request URLs from a website via Playwright
# Usage: playwright-capture.sh <url> <env>
#   url:  target URL, e.g. https://www.example.com/
#   env:  "host" or "ddev"
# Output: one URL per line to stdout

set -euo pipefail

URL="${1:?Usage: playwright-capture.sh <url> <env>}"
ENV="${2:?Usage: playwright-capture.sh <url> <env>}"

# Validate URL is HTTP(S)
if [[ ! "$URL" =~ ^https?:// ]]; then
  echo "ERROR: url must start with http:// or https://" >&2
  exit 1
fi

# Validate ENV parameter
if [[ "$ENV" != "host" && "$ENV" != "ddev" ]]; then
  echo "ERROR: env must be 'host' or 'ddev', got: $ENV" >&2
  exit 1
fi

CAPTURE_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/capture-urls-XXXXXX.cjs")"
trap 'rm -f "$CAPTURE_SCRIPT"' EXIT

# Write the capture script
cat > "$CAPTURE_SCRIPT" << 'SCRIPT'
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  const urls = new Set();
  page.on('request', r => urls.add(r.url()));
  await page.goto(process.argv[2], { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.evaluate(async () => {
    await new Promise(resolve => {
      const distance = window.innerHeight;
      const delay = 300;
      const timer = setInterval(() => {
        window.scrollBy(0, distance);
        if (window.scrollY + window.innerHeight >= document.body.scrollHeight) {
          clearInterval(timer);
          window.scrollTo(0, 0);
          resolve();
        }
      }, delay);
    });
  });
  await page.waitForTimeout(3000);
  [...urls].forEach(u => console.log(u));
  await browser.close();
})();
SCRIPT

if [[ "$ENV" == "host" ]]; then
  NODE_PATH="$(npm root -g)" node "$CAPTURE_SCRIPT" "$URL" 2>/dev/null
elif [[ "$ENV" == "ddev" ]]; then
  # Copy script into ddev container and run there
  ddev exec bash -c "cat > /tmp/_capture-urls.cjs" < "$CAPTURE_SCRIPT"
  ddev exec node /tmp/_capture-urls.cjs "$URL" 2>/dev/null
fi
