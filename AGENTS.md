# Grove development instructions

This file contains technical instructions for agents and contributors. User
documentation is in [README.md](README.md).

## Project scope

Grove is a native macOS menu bar app and local MCP server.

- Swift, SwiftUI, AppKit, EventKit, and Swift Package Manager.
- macOS 14 or later.
- Calendar and Reminders are the current integrations.
- MCP uses a localhost HTTP endpoint when the app runs. `--mcp` remains a
  stdio fallback for clients that launch the executable.
- The app has no database and does not keep a second copy of Apple data.

Keep new work local, native, and small. Do not add cloud services, accounts,
polling loops, or a database without a clear product requirement.

## Project layout

- `Grove.xcodeproj`: primary macOS app project.
- `Grove/`: app, menu bar UI, EventKit store, MCP server, settings, and process lifecycle.
- `GroveTests/`: focused SwiftPM tests.
- `script/build_and_run.sh`: local build and run helper.
- `script/package_release.sh`: lower-level signed packaging command.
- `script/release-sparkle.sh`: guarded release and publication command.
- `skills/grove/SKILL.md`: portable agent instructions for Grove tools.
- `website/`: GitHub Pages site and architecture-specific appcasts.

## Build and run

Use the helper for normal local work:

```sh
./script/build_and_run.sh
./script/build_and_run.sh doctor
./script/build_and_run.sh authorize
./script/build_and_run.sh --verify
```

The helper builds an unsigned Debug app in:

```text
build/GroveDerivedData/Build/Products/Debug/Grove.app
```

Build the Xcode target directly when needed:

```sh
xcodebuild -project Grove.xcodeproj \
  -scheme Grove \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/GroveDerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

Run SwiftPM tests with `swift test` when the change affects tested behavior.
Do not run broad builds or tests for a documentation-only change.

## MCP registration

When Grove starts, it starts the local MCP endpoint:

```text
http://127.0.0.1:52718/mcp
```

The endpoint listens on loopback only. It does not expose Grove to the local
network or the internet.

Clients that support local HTTP MCP can use that URL. Grove also supports the
stdio command:

```text
Grove.app/Contents/MacOS/Grove --mcp
```

Before starting an MCP client:

1. Open Grove.
2. Enable Calendar or Reminders in the menu bar panel.
3. Grant the requested macOS permissions.
4. Add the local HTTP endpoint or the stdio command to the MCP client.

The menu bar selection controls the active tool list. Grove reads the current
selection for every request and sends `notifications/tools/list_changed` when
the selection changes. Existing clients do not need a server restart.

### Codex

For the app-owned local HTTP server:

```sh
codex mcp add grove --url http://127.0.0.1:52718/mcp
```

For a release app:

```sh
codex mcp add grove -- /Applications/Grove.app/Contents/MacOS/Grove --mcp
```

For a local Debug build:

```sh
codex mcp add grove -- \
  "$PWD/build/GroveDerivedData/Build/Products/Debug/Grove.app/Contents/MacOS/Grove" \
  --mcp
```

Verify the registration with:

```sh
codex mcp get grove
```

### JSON clients

Clients that use a JSON MCP configuration use the same stdio command:

```json
{
  "mcpServers": {
    "grove": {
      "command": "/Applications/Grove.app/Contents/MacOS/Grove",
      "args": ["--mcp"]
    }
  }
}
```

Use the client’s own configuration location and restart it after editing the
file. Do not assume that one client’s configuration format applies to another.

There is no shared macOS-wide MCP auto-discovery or configuration standard.
MCP capability discovery happens after a client connects to a known server.
Keep setup explicit and ask for consent before changing a client’s files.

## Agent skill

The Grove skill is at `skills/grove/SKILL.md`.

For a local Codex skill installation:

```sh
mkdir -p ~/.codex/skills/grove
cp skills/grove/SKILL.md ~/.codex/skills/grove/SKILL.md
```

Start a new Codex session after installing the skill. The skill explains date
formats, recurrence scope, identifier lookup, and safe mutation rules.

Do not install the skill or edit agent configuration without user consent. A
future first-launch setup may offer these actions after detecting a supported
client. It must show what it will change and allow the user to decline.

## Architecture

The same executable has two modes:

- Menu bar mode: `MenuBarExtra` shows service toggles, app controls, and starts
  the loopback MCP server.
- Headless mode: `--mcp` starts the stdio MCP server for clients that need a
  command.

The menu bar app owns the loopback listener and active stdio process leases.
Quitting Grove stops the listener and terminates those processes.
`GroveSettings` stores service choices and manages the login item.
`EventKitStore` owns Calendar and Reminders access. `MCPServer` exposes only the
enabled service tools.

Keep these responsibilities separate. Prefer SwiftUI and system controls. Use
AppKit only where macOS behavior requires it.

## Release

Do not release from an uncommitted or mixed worktree. Release signing remains a
manual, credentialed operation.

Submit a first notarization without waiting for Apple:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: ..." \
NOTARY_PROFILE="XCode Notary" \
RELEASE_NOTES_FILE="docs/releases/0.2.0.md" \
WAIT_FOR_NOTARIZATION=NO ./script/release-sparkle.sh 0.2.0 2
```

The script checks the version, build number, notes, and worktree. It builds
signed Apple silicon and Intel DMGs, submits both DMGs, and records Apple
requests in `dist/notarization-*.json`. It does not publish an
unnotarized app.

Check and finalize the release after Apple accepts it:

```sh
NOTARY_PROFILE="XCode Notary" ./script/check_notarization.sh
NOTARY_PROFILE="XCode Notary" ./script/finalize_notarization.sh
PREPARED_RELEASE=YES RELEASE_NOTES_FILE="docs/releases/0.2.0.md" \
  ./script/release-sparkle.sh 0.2.0 2
```

The final release step creates a signed Git tag, publishes the Apple silicon
and Intel GitHub Release assets and their architecture-specific appcasts, and
starts the GitHub Pages deployment. The website download button selects the
native archive. Sparkle selects the matching appcast at runtime.

Required private values must stay outside the repository:

- Developer ID certificate and signing identity.
- Apple notarization credentials.
- Sparkle EdDSA private key.

Use `script/package_release.sh` only when preparing the package without the
final GitHub publication step.

## Code and documentation rules

- Keep code lean. Add a TODO for a useful future improvement when it is not part of the current task.
- Prefer a small clear abstraction over defensive layers for hypothetical failures.
- Add validation for permissions, destructive operations, process lifecycle, and other real failure modes.
- Use native macOS controls and system-adaptive colors.
- Keep user-facing copy short and direct.
- Add focused tests when behavior is important. Do not add tests only to increase coverage.
- Preserve unrelated work and inspect `git status` before editing.
