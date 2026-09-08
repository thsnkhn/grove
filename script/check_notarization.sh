#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
NOTARY_PROFILE="${NOTARY_PROFILE:-XCode Notary}"

[[ -n "$NOTARY_PROFILE" ]] || {
  echo "Set NOTARY_PROFILE to the keychain profile used for submission." >&2
  exit 1
}

if [[ $# -gt 0 ]]; then
  RECORDS=("$@")
else
  RECORDS=(
    "$DIST_DIR/notarization-apple-silicon.json"
    "$DIST_DIR/notarization-intel.json"
  )
fi

found_record=NO
for record in "${RECORDS[@]}"; do
  [[ -f "$record" ]] || continue
  found_record=YES

  SUBMISSION_ID="$(sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$record" | head -n 1)"
  [[ -n "$SUBMISSION_ID" ]] || {
    echo "No submission ID found in $record." >&2
    exit 1
  }

  echo "Checking $(basename "$record") request $SUBMISSION_ID..."
  xcrun notarytool info "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE"
done

[[ "$found_record" == YES ]] || {
  echo "No notarization records found in $DIST_DIR." >&2
  exit 1
}
