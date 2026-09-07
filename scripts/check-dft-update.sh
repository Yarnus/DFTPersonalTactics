#!/usr/bin/env bash
set -eu

SITE_URL="https://dreamforgewow.com/?lng=en-US"
META_URL="https://dreamsrstorage.blob.core.windows.net/wowhead-assets/dft-meta.json"
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DFT_TOC="${DFT_TOC:-$ROOT/../DreamForgeTools/DreamForgeTools.toc}"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if [ ! -f "$DFT_TOC" ]; then
  printf 'DFT TOC not found: %s\n' "$DFT_TOC" >&2
  exit 2
fi

VERSION="$(awk -F': *' '$1 == "## Version" { print $2; exit }' "$DFT_TOC")"
if [ -z "$VERSION" ]; then
  printf 'Could not read DreamForgeTools version from %s\n' "$DFT_TOC" >&2
  exit 2
fi

HTTP="$(curl --fail --silent --show-error --location --user-agent 'DFTPersonalTactics compatibility checker' --output "$TMP" --write-out '%{http_code}' "$META_URL" || true)"
case "$HTTP" in
  2[0-9][0-9]) ;;
  *)
    printf 'DreamForge update metadata check failed (HTTP %s): %s\n' "${HTTP:-no response}" "$META_URL" >&2
    exit 3
    ;;
esac

REMOTE="$(awk -F'"' '/"version"[[:space:]]*:/ { print $4; exit }' "$TMP")"
REMOTE="${REMOTE#V}"
if [ -z "$REMOTE" ]; then
  printf 'DreamForge metadata exposed no release version: %s\n' "$META_URL" >&2
  printf 'Inspect the download page manually before updating or releasing this addon: %s\n' "$SITE_URL" >&2
  exit 4
fi

LOCAL_SORT_KEY="$(printf '%s\n' "$VERSION" | awk -F. '{ print $1 $2 $3 }')"
REMOTE_SORT_KEY="$(printf '%s\n' "$REMOTE" | awk -F. '{ print $1 $2 $3 }')"
if [ "$REMOTE_SORT_KEY" -gt "$LOCAL_SORT_KEY" ]; then
  printf 'DreamForgeTools update detected: local %s, official download %s.\n' "$VERSION" "$REMOTE" >&2
  printf 'Review DFT API changes before updating or releasing this addon.\n' >&2
  exit 5
fi

printf 'Official DreamForge download metadata reachable; local DreamForgeTools version %s is current against %s.\n' "$VERSION" "$REMOTE"
