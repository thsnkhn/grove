#!/usr/bin/env bash
set -euo pipefail

# Build, sign, notarize, tag, and publish one Grove release.
# Usage: RELEASE_NOTES_FILE=docs/releases/0.1.0.md script/release-sparkle.sh 0.1.0 2

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITHUB_REPO="${GITHUB_REPO:-thsnkhn/grove}"
TAG_REMOTE="${TAG_REMOTE:-origin}"
SOURCE_VERSION="$(sed -n 's/.*static let version = "\([^"]*\)".*/\1/p' "$ROOT_DIR/Grove/GroveApp.swift")"
REQUESTED_VERSION="${1:-}"
VERSION="${REQUESTED_VERSION#v}"
BUILD_NUMBER="${2:-${GROVE_BUILD_NUMBER:-}}"
RELEASE_TAG="v$VERSION"
ZIP_PATH="$ROOT_DIR/dist/Grove-$VERSION.zip"
APPLE_SILICON_ZIP="$ROOT_DIR/dist/Grove-Apple-Silicon.zip"
INTEL_ZIP="$ROOT_DIR/dist/Grove-Intel.zip"
CHECKSUM_PATH="$ROOT_DIR/dist/SHA256SUMS"
APPCAST_PATH="$ROOT_DIR/dist/appcast.xml"
WAIT_FOR_NOTARIZATION="${WAIT_FOR_NOTARIZATION:-YES}"
PREPARED_RELEASE="${PREPARED_RELEASE:-NO}"
PUBLISH_EXISTING_RELEASE="${PUBLISH_EXISTING_RELEASE:-NO}"

usage() {
  echo "Usage: RELEASE_NOTES_FILE=<path> $0 <version> <build-number>" >&2
}

if [[ $# -lt 1 || $# -gt 2 || -z "$BUILD_NUMBER" ]]; then
  usage
  exit 1
fi

[[ "$PUBLISH_EXISTING_RELEASE" == "YES" || "$PUBLISH_EXISTING_RELEASE" == "NO" ]] || {
  echo "PUBLISH_EXISTING_RELEASE must be YES or NO." >&2
  exit 1
}

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Version must use x.y.z." >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo "Build number must be a positive integer." >&2; exit 1; }

if [[ "$VERSION" != "$SOURCE_VERSION" ]]; then
  echo "Version $VERSION does not match Grove.version $SOURCE_VERSION." >&2
  exit 1
fi

if [[ -n "${RELEASE_NOTES_FILE:-}" ]]; then
  [[ -f "$RELEASE_NOTES_FILE" ]] || { echo "Release notes file not found: $RELEASE_NOTES_FILE" >&2; exit 1; }
  RELEASE_NOTES_FILE="$(cd "$(dirname "$RELEASE_NOTES_FILE")" && pwd)/$(basename "$RELEASE_NOTES_FILE")"
elif [[ -z "${RELEASE_NOTES:-}" ]]; then
  echo "Set RELEASE_NOTES_FILE or RELEASE_NOTES." >&2
  exit 1
fi

cd "$ROOT_DIR"

if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  echo "Working tree is dirty. Commit or stash changes before release." >&2
  git status --short >&2
  exit 1
fi

if [[ "$PREPARED_RELEASE" == "YES" ]]; then
  echo "Using prepared Grove $VERSION ($BUILD_NUMBER) artifacts."
  APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/dist/Grove.app/Contents/Info.plist" 2>/dev/null || true)"
  APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT_DIR/dist/Grove.app/Contents/Info.plist" 2>/dev/null || true)"
  [[ "$APP_VERSION" == "$VERSION" && "$APP_BUILD" == "$BUILD_NUMBER" ]] || {
    echo "Prepared app version/build does not match $VERSION ($BUILD_NUMBER)." >&2
    exit 1
  }
else
  echo "Preparing Grove $VERSION ($BUILD_NUMBER)..."
  GROVE_VERSION="$VERSION" GROVE_BUILD_NUMBER="$BUILD_NUMBER" \
    WAIT_FOR_NOTARIZATION="$WAIT_FOR_NOTARIZATION" \
    "$ROOT_DIR/script/package_release.sh"

  if [[ "$WAIT_FOR_NOTARIZATION" == "NO" ]]; then
    echo "Notarization is pending. Run script/check_notarization.sh later."
    exit 0
  fi
fi

ARTIFACTS=("$ZIP_PATH" "$APPLE_SILICON_ZIP" "$INTEL_ZIP")
for artifact in "${ARTIFACTS[@]}" "$CHECKSUM_PATH" "$APPCAST_PATH"; do
  [[ -f "$artifact" ]] || { echo "Missing release artifact: $artifact" >&2; exit 1; }
done

if git rev-parse --verify --quiet "refs/tags/$RELEASE_TAG" >/dev/null; then
  echo "Using existing local tag $RELEASE_TAG."
elif git ls-remote --exit-code --tags "$TAG_REMOTE" "refs/tags/$RELEASE_TAG" >/dev/null 2>&1; then
  git fetch "$TAG_REMOTE" "refs/tags/$RELEASE_TAG:refs/tags/$RELEASE_TAG"
else
  echo "Creating signed tag $RELEASE_TAG..."
  git tag -s "$RELEASE_TAG" -m "Grove $VERSION"
fi

if [[ "$PUBLISH_EXISTING_RELEASE" != "YES" && "$(git rev-list -n 1 "$RELEASE_TAG")" != "$(git rev-parse HEAD)" ]]; then
  echo "Tag $RELEASE_TAG does not point to HEAD." >&2
  exit 1
fi

if ! git ls-remote --exit-code --tags "$TAG_REMOTE" "refs/tags/$RELEASE_TAG" >/dev/null 2>&1; then
  git push "$TAG_REMOTE" "$RELEASE_TAG"
fi

if ! gh release view "$RELEASE_TAG" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
  echo "Creating GitHub release $RELEASE_TAG..."
  release_args=(
    "$RELEASE_TAG"
    --repo "$GITHUB_REPO"
    --verify-tag
    --title "Grove $VERSION"
  )

  if [[ -n "${RELEASE_NOTES_FILE:-}" ]]; then
    release_args+=(--notes-file "$RELEASE_NOTES_FILE")
  else
    release_args+=(--notes "$RELEASE_NOTES")
  fi

  gh release create "${release_args[@]}"
fi

echo "Uploading release artifacts..."
gh release upload "$RELEASE_TAG" "${ARTIFACTS[@]}" "$CHECKSUM_PATH" "$APPCAST_PATH" \
  --repo "$GITHUB_REPO" \
  --clobber

echo "Deploying the updated appcast to GitHub Pages..."
gh workflow run pages.yml --repo "$GITHUB_REPO"

echo "Published Grove $VERSION ($BUILD_NUMBER)."
echo "Release: https://github.com/$GITHUB_REPO/releases/tag/$RELEASE_TAG"
echo "Feed: https://thsnkhn.github.io/grove/appcast.xml"
