#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Grove"
SCHEME="Grove"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/build/GroveDerivedData"
HOST_ARCH="${GROVE_ARCH:-$(uname -m)}"

case "$HOST_ARCH" in
  arm64|x86_64) ;;
  *)
    echo "Unsupported macOS architecture: $HOST_ARCH" >&2
    exit 2
    ;;
esac

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$ROOT_DIR/Grove.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=macOS,arch=$HOST_ARCH" \
  -derivedDataPath "$DERIVED_DATA" \
  -sdk macosx \
  ARCHS="$HOST_ARCH" \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

case "$MODE" in
  run)
    /usr/bin/open -n "$APP_BUNDLE"
    ;;
  doctor|authorize|--help|-h|--version|-v)
    "$APP_BINARY" "$MODE"
    ;;
  --mcp|mcp)
    "$APP_BINARY" --mcp
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --verify|verify)
    OUTPUT="$(
      {
        printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"grove-smoke","version":"0.1"}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
        sleep 0.5
      } | "$APP_BINARY" --mcp
    )"
    rg -q '"name":"grove"' <<< "$OUTPUT"
    rg -q '"tools"' <<< "$OUTPUT"
    ;;
  *)
    echo "usage: $0 [run|--mcp|doctor|authorize|--help|--version|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
