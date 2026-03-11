# SS Copy Assets

Downloads images and videos from a live SilverStripe website to local `assets/` using Playwright network capture and a helper script.

## Usage

```
/ss-copy-assets [URL]
```

## Instructions

### 1. Detect SilverStripe Version

Read `composer.json`: look for `"silverstripe/framework"`.
- `~3.` or `3.x-dev` → SS version **3**
- `^4` or `^5` → SS version **4**

### 2. Ensure ddev is running

Run `ddev describe`, start if needed.

### 3. Capture Network Request URLs

**If MCP browser tools are available** (`browser_navigate`, `browser_evaluate`, etc.) — use them directly:

1. Open the URL with `browser_navigate`
2. Scroll incrementally to trigger lazy-loaded images using `browser_evaluate`:

```javascript
async () => {
  await new Promise((resolve) => {
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
}
```

3. Wait 3 seconds: `browser_wait_for(time: 3)`
4. Capture requests: `browser_network_requests(includeStatic: true)`

**If MCP browser tools are NOT available** — use the bash scripts:

```bash
ENV=$(~/.claude/scripts/playwright-setup.sh)
~/.claude/scripts/playwright-capture.sh <TARGET_URL> "$ENV"
```

`playwright-setup.sh` auto-detects Playwright on host or ddev, installs it if missing, configures the MCP server for future sessions, and outputs `host` or `ddev`.

`playwright-capture.sh` runs headless Chromium, scrolls the page, and outputs all network request URLs to stdout.

### 4. Download via Helper Script

Pipe the captured URLs into the download script:

```bash
echo "<NETWORK_REQUEST_URLS>" | ~/.claude/scripts/copy-images.sh <base_url> <ss_version>
```

- `<base_url>`: the site origin, e.g. `https://www.example.com`
- `<ss_version>`: `3` or `4` (from step 1)

### Critical Rules

1. **ALWAYS detect SS version** from `composer.json` before running the script
2. **ALWAYS use network capture** (MCP or bash scripts) — never parse HTML
3. **ALWAYS scroll incrementally** (one viewport at a time, 300ms delay) — a single `scrollTo(bottom)` misses lazy-loaded images
4. **ALWAYS wait 3 seconds** after scrolling before capturing network requests
