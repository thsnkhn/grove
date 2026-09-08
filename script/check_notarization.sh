#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RECORD_PATH="${1:-$ROOT_DIR/dist/notarization.json}"
NOTARY_PROFILE="${NOTARY_PROFILE:-XCode Notary}"

[[ -f "$RECORD_PATH" ]] || {
  echo "Notarization record not found: $RECORD_PATH" >&2
  exit 1
}
[[ -n "$NOTARY_PROFILE" ]] || {
  echo "Set NOTARY_PROFILE to the keychain profile used for submission." >&2
  exit 1
}

SUBMISSION_ID="$(sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$RECORD_PATH" | head -n 1)"
[[ -n "$SUBMISSION_ID" ]] || {
  echo "No submission ID found in $RECORD_PATH." >&2
  exit 1
}

echo "Checking notarization request $SUBMISSION_ID..."
xcrun notarytool info "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE"
