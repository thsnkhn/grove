#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="grove"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
swift build
APP_BINARY="$(swift build --show-bin-path)/$APP_NAME"

case "$MODE" in
  run)
    "$APP_BINARY"
    ;;
  doctor|authorize|--help|-h|--version|-v)
    "$APP_BINARY" "$MODE"
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    "$APP_BINARY" &
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    "$APP_BINARY" &
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --verify|verify)
    OUTPUT="$(
      {
        printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"grove-smoke","version":"0.1"}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
        sleep 0.5
      } | "$APP_BINARY"
    )"
    rg -q '"name":"grove"' <<< "$OUTPUT"
    rg -q '"tools"' <<< "$OUTPUT"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
