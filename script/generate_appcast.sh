#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="${1:?Pass the signed, notarized Grove DMG.}"
FEED_NAME="${2:?Pass the architecture-specific appcast filename.}"
TOOLS="${SPARKLE_BIN_DIR:-$ROOT_DIR/build/ReleaseDerivedData/arm64/SourcePackages/artifacts/sparkle/Sparkle/bin}"
VERSION="$(sed -n 's/.*static let version = "\([^"]*\)".*/\1/p' "$ROOT_DIR/Grove/GroveApp.swift")"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/grove-appcast.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

ARCHIVE_NAME="$(basename "$ARCHIVE")"
TEMPLATE="$ROOT_DIR/website/$FEED_NAME"
[[ -f "$TEMPLATE" ]] || { echo "Appcast template not found: $TEMPLATE" >&2; exit 1; }

cp "$ARCHIVE" "$STAGING/$ARCHIVE_NAME"
cp "$TEMPLATE" "$STAGING/appcast.xml"
SIGNING=(--account com.thsnkhn.grove)
if [[ -n "${SPARKLE_ED_KEY_FILE:-}" ]]; then
  SIGNING=(--ed-key-file "$SPARKLE_ED_KEY_FILE")
fi

# TODO: Add delta archives when release size justifies keeping older DMGs here.
"$TOOLS/generate_appcast" "${SIGNING[@]}" \
  --maximum-deltas 0 \
  --download-url-prefix "https://github.com/thsnkhn/grove/releases/download/v$VERSION/" \
  --full-release-notes-url "https://github.com/thsnkhn/grove/releases/tag/v$VERSION" \
  --link "https://thsnkhn.github.io/grove/" \
  "$STAGING"

# Never publish a feed if signing failed or the archive used a different key.
signature=$(/usr/bin/xmllint --xpath 'string(/rss/channel/item/enclosure/@*[local-name()="edSignature"])' "$STAGING/appcast.xml")
[[ -n "$signature" ]] || { echo "Appcast has no EdDSA signature." >&2; exit 1; }
swift "$ROOT_DIR/script/verify_update.swift" "$ARCHIVE" "$signature" \
  "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$ROOT_DIR/Grove/Info.plist")"

mkdir -p "$ROOT_DIR/dist"
cp "$STAGING/appcast.xml" "$ROOT_DIR/dist/$FEED_NAME"
