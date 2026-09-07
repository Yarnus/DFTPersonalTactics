#!/usr/bin/env bash
set -eu

META_URL="https://dreamsrstorage.blob.core.windows.net/wowhead-assets/dft-meta.json"
OUTPUT_ROOT="${1:-${TMPDIR:-/tmp}/dft-upstream}"
META_TMP="$(mktemp)"
ZIP_TMP="$(mktemp)"
trap 'rm -f "$META_TMP" "$ZIP_TMP"' EXIT

mkdir -p "$OUTPUT_ROOT"
curl --fail --silent --show-error --location --user-agent 'DFTPersonalTactics source fetcher' --output "$META_TMP" "$META_URL"
VERSION="$(awk -F'"' '/"version"[[:space:]]*:/ { print $4; exit }' "$META_TMP")"
DOWNLOAD_URL="$(awk -F'"' '/"downloadUrl"[[:space:]]*:/ { print $4; exit }' "$META_TMP")"
VERSION="${VERSION#V}"

if [ -z "$VERSION" ] || [ -z "$DOWNLOAD_URL" ]; then
  printf 'Official metadata is missing version or downloadUrl: %s\n' "$META_URL" >&2
  exit 2
fi

DEST="$OUTPUT_ROOT/DreamForgeTools-$VERSION"
rm -rf "$DEST"
mkdir -p "$DEST"
curl --fail --silent --show-error --location --user-agent 'DFTPersonalTactics source fetcher' --output "$ZIP_TMP" "$DOWNLOAD_URL"
unzip -q "$ZIP_TMP" -d "$DEST"

SOURCE_DIR="$DEST"
if [ -d "$DEST/DreamForgeTools" ]; then
  SOURCE_DIR="$DEST/DreamForgeTools"
fi

printf 'Downloaded DreamForgeTools %s\n' "$VERSION"
printf 'Source directory: %s\n' "$SOURCE_DIR"
printf 'Archive URL: %s\n' "$DOWNLOAD_URL"
