# ss-copy-assets

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill that downloads images and videos from a live SilverStripe website to your local `assets/` directory using Playwright network capture. Supports SilverStripe 3 and 4+ asset formats.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- Node.js + npm
- [ddev](https://ddev.readthedocs.io/) (for local SilverStripe development)

## Installation

```bash
git clone https://github.com/mhilla/ss-copy-assets.git
cd ss-copy-assets
./install.sh
```

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
└── scripts/
    ├── playwright-setup.sh            # Playwright detection/install
    ├── playwright-capture.sh          # Network URL capture
    └── copy-images.sh                 # Asset downloader
```

## License

MIT
