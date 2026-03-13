# ss-copy-assets

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill that downloads images and videos from a live SilverStripe website to your local `assets/` directory using Playwright network capture. Supports SilverStripe 3 and 4+ asset formats.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- Node.js >= 18
- [ddev](https://ddev.readthedocs.io/) (for local SilverStripe development)

## Installation

```bash
git clone https://github.com/mvn-neumann/ss-copy-assets.git
cd ss-copy-assets
./install.sh
```

The installer:
1. Copies skill files and scripts to `~/.claude/`
2. Installs Playwright as an npm module to `~/.claude/lib/` (no sudo required)

After install, run the setup script to install Chromium and configure the MCP server:

```bash
~/.claude/scripts/playwright-setup.sh
```

If Chromium can't launch on the host (missing system libraries), the setup automatically falls back to running inside the ddev container.

### System dependencies (optional)

For running Chromium on the host (WSL/native Linux), you may need:

```bash
sudo npx playwright install-deps chromium
```

This is not needed if you use the ddev fallback.

## Usage

Inside your SilverStripe project directory, run:

```
/ss-copy-assets https://www.example.com/
```

Claude will:

1. Detect the SilverStripe version from `composer.json`
2. Launch headless Chromium via Playwright
3. Scroll the page to trigger lazy-loaded images
4. Capture all network request URLs
5. Filter for `/assets/` images and videos
6. Download them to your local `assets/` directory

## How It Works

1. **`playwright-setup.sh`** — Detects or installs Playwright + Chromium (host or ddev), configures the MCP server
2. **`playwright-capture.sh`** — Runs headless Chromium, scrolls the target page, outputs all network request URLs
3. **`copy-images.sh`** — Filters URLs for `/assets/` images/videos, derives original (non-resampled) URLs, downloads via curl

## What Gets Installed

```
~/.claude/
├── skills/
│   ├── ss-copy-assets.md              # Skill instructions
│   └── ss-copy-assets/
│       └── SKILL.md                   # Skill metadata
├── scripts/
│   ├── playwright-setup.sh            # Playwright detection/install
│   ├── playwright-capture.sh          # Network URL capture
│   └── copy-images.sh                 # Asset downloader
└── lib/
    └── node_modules/playwright        # Playwright npm module
```

## License

MIT
