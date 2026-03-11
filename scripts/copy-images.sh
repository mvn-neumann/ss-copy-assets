#!/usr/bin/env bash
# copy-images.sh — Download /assets/ images and videos from network request URLs
# Usage: echo "<urls>" | copy-images.sh <base_url> <ss_version>
#   base_url:    e.g. https://www.example.com
#   ss_version:  3 or 4

set -euo pipefail

BASE_URL="${1:?Usage: copy-images.sh <base_url> <ss_version>}"
SS_VERSION="${2:?Usage: copy-images.sh <base_url> <ss_version>}"

# Validate BASE_URL is an HTTP(S) URL
if [[ ! "$BASE_URL" =~ ^https?:// ]]; then
  echo "ERROR: base_url must start with http:// or https://" >&2
  exit 1
fi

# Validate SS_VERSION is 3 or 4
if [[ "$SS_VERSION" != "3" && "$SS_VERSION" != "4" ]]; then
  echo "ERROR: ss_version must be 3 or 4, got: $SS_VERSION" >&2
  exit 1
fi

# Strip trailing slash from base URL
BASE_URL="${BASE_URL%/}"

# Read URLs from stdin, filter for /assets/ images+videos, strip query strings, deduplicate
mapfile -t URLS < <(
  grep -iE '/assets/.*\.(png|jpe?g|webp|svg|gif|mp4|webm|mov|avi|ogv)(\?|$)' |
  sed 's/\?.*//' |
  sort -uf
)

if [[ ${#URLS[@]} -eq 0 ]]; then
  echo "No /assets/ image/video URLs found in input."
  exit 0
fi

# Derive original URL from a manipulated one
derive_original() {
  local url="$1"
  if [[ "$SS_VERSION" == "3" ]]; then
    if [[ "$url" == *"/_resampled/"* ]]; then
      echo "$url" | sed -E 's|/_resampled/[^/]+/|/|'
    fi
  else
    if echo "$url" | grep -qE '__[A-Z][A-Za-z]+[A-Z][A-Za-z0-9=]+\.[a-zA-Z]+$'; then
      echo "$url" | sed -E 's/__[A-Z][A-Za-z]+[A-Z][A-Za-z0-9=]+(\.[a-zA-Z]+)$/\1/'
    fi
  fi
}

# Collect all URLs to download (network + derived originals), deduplicated
declare -A SEEN
ALL_URLS=()

for url in "${URLS[@]}"; do
  # Ensure full URL and determine download URL
  if [[ "$url" == /* ]]; then
    full_url="${BASE_URL}${url}"
    download_url="$full_url"
  elif [[ "$url" == "${BASE_URL}"/* ]]; then
    full_url="$url"
    download_url="$full_url"
  elif [[ "$url" =~ \.imgix\.net/ ]]; then
    # imgix-hosted assets: extract /assets/... path, download from imgix
    asset_path="${url#*imgix.net}"
    full_url="${BASE_URL}${asset_path}"
    download_url="$url"
  else
    # Skip other external URLs
    continue
  fi

  if [[ -z "${SEEN[$full_url]:-}" ]]; then
    SEEN[$full_url]=1
    ALL_URLS+=("$full_url|$download_url")
  fi

  # Derive original
  orig=$(derive_original "$full_url")
  if [[ -n "$orig" && -z "${SEEN[$orig]:-}" ]]; then
    SEEN[$orig]=1
    # For imgix originals, derive the imgix download URL too
    orig_download=$(derive_original "$download_url")
    ALL_URLS+=("$orig|${orig_download:-$orig}")
  fi
done

# Download
ok=0; skip=0; fail=0; deriv=0
declare -A EXT_COUNT

for entry in "${ALL_URLS[@]}"; do
  # Split "local_url|download_url"
  url="${entry%%|*}"
  download_url="${entry##*|}"

  # Extract relative path from URL
  rel_path="${url#"$BASE_URL"}"
  rel_path="${rel_path#/}"

  # Security: reject path traversal attempts and absolute paths
  if [[ "$rel_path" == /* || "$rel_path" == *".."* ]]; then
    echo "WARN: Skipping unsafe path: $rel_path" >&2
    fail=$((fail + 1))
    continue
  fi

  # Skip if file already exists and is non-empty
  if [[ -s "$rel_path" ]]; then
    skip=$((skip + 1))
    continue
  fi

  mkdir -p "$(dirname "$rel_path")"
  http_code=$(curl -sL -o "$rel_path" -w "%{http_code}" "$download_url" 2>/dev/null || echo "000")

  if [[ "$http_code" =~ ^2 ]] && [[ -s "$rel_path" ]]; then
    ok=$((ok + 1))
    ext="${rel_path##*.}"
    ext="${ext,,}"
    EXT_COUNT[$ext]=$(( ${EXT_COUNT[$ext]:-0} + 1 ))
  else
    rm -f "$rel_path"
    fail=$((fail + 1))
  fi
done

# Summary
echo "--- Copy Assets Summary ---"
echo "Downloaded: $ok  |  Skipped (existing): $skip  |  Failed/404: $fail"
if [[ "$ok" -gt 0 ]]; then
  echo -n "By type:"
  for ext in "${!EXT_COUNT[@]}"; do
    echo -n "  .$ext=${EXT_COUNT[$ext]}"
  done
  echo
fi
