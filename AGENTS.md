# Grove development instructions

This file contains technical instructions for agents and contributors. User
documentation is in [README.md](README.md).

## Project scope

Grove is a native macOS menu bar app and local MCP server.

- Swift, SwiftUI, AppKit, EventKit, and Swift Package Manager.
- macOS 14 or later.
- Calendar and Reminders are the current integrations.
- MCP uses stdio. There is no network listener.
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
- `website/`: GitHub Pages site and initial appcast.

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

Grove starts its MCP server from the app executable:

```text
Grove.app/Contents/MacOS/Grove --mcp
```

Before starting an MCP client:

1. Open Grove.
2. Enable Calendar or Reminders in the menu bar panel.
3. Grant the requested macOS permissions.
4. Add Grove to the MCP client.

The enabled service set is read when the MCP process starts. Restart the MCP
client after changing service toggles.

### Codex

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

- Menu bar mode: `MenuBarExtra` shows service toggles and app controls.
- Headless mode: `--mcp` starts the stdio MCP server.

The menu bar app owns active MCP process leases. Quitting Grove terminates those
processes. `GroveSettings` stores service choices and manages the login item.
`EventKitStore` owns Calendar and Reminders access. `MCPServer` exposes only the
enabled service tools.

Keep these responsibilities separate. Prefer SwiftUI and system controls. Use
AppKit only where macOS behavior requires it.

## Release

Do not release from an uncommitted or mixed worktree. Release signing remains a
manual, credentialed operation.

Prepare a release with:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: ..." \
APPLE_ID="..." \
APPLE_TEAM_ID="..." \
NOTARYTOOL_PASSWORD="..." \
RELEASE_NOTES_FILE="docs/releases/0.1.0.md" \
./script/release-sparkle.sh 0.1.0 2
```

The script checks the version, build number, notes, and worktree. It builds an
arm64/x86_64 app, signs Sparkle, notarizes and staples the app, generates a
signed appcast, creates a signed Git tag, publishes GitHub Release assets, and
starts the GitHub Pages deployment.

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
