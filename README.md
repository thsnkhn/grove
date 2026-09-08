# Grove

Native Mac tools for AI assistants.

[![CI](https://github.com/thsnkhn/grove/actions/workflows/ci.yml/badge.svg)](https://github.com/thsnkhn/grove/actions/workflows/ci.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![Swift 6+](https://img.shields.io/badge/Swift-6%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![MCP](https://img.shields.io/badge/Protocol-MCP-555555)](https://modelcontextprotocol.io/)
[![License](https://img.shields.io/github/license/thsnkhn/grove)](https://github.com/thsnkhn/grove/blob/main/LICENSE)
[![Early development](https://img.shields.io/badge/Status-early_development-D4A017)](https://github.com/thsnkhn/grove)

Grove is a small, local macOS menu bar app and MCP server. It gives AI assistants access to Apple Calendar and Reminders through Swift and EventKit. More native Apple app integrations can follow.

Grove has one native menu bar surface. It has no database, network listener, or polling loop. The same app executable also supports the MCP stdio process started by an MCP client.

Grove is free and open source under GPL-3.0.

## Current status

The first working prototype is available. It supports Calendar and Reminders CRUD, common repeat schedules, time alarms, date filters, and local stdio MCP transport. The menu bar app controls which service groups the MCP process exposes.

## Features

Calendar tools:

- List calendars.
- List events in a date range.
- Read, create, update, and delete events.
- Support all-day events, time zones, recurrence, and alarms.

Reminders tools:

- List reminder lists.
- List reminders by status, list, due range, or text.
- Read, create, update, complete, reopen, and delete reminders.
- Support due dates, priorities, recurrence, and alarms.

Menu bar:

- Use `tree.fill` as the Grove status icon.
- Enable Calendar and Reminders independently.
- Start Grove at login with the native macOS login-item service.
- Quit Grove and its registered MCP processes together.
- Check for updates with Sparkle from **Check for Updates…**.
- Check automatically by default, with a switch to turn checks off.

The initial interface has 12 explicit tools. It does not include Calendar-list creation, Reminder-list creation, attendees, location alarms, native Reminders tags, sections, subtasks, or batch operations.

## Requirements

- macOS 14 or later.
- Xcode 16 or later for the Xcode project.
- Swift 6 or later for source builds.
- Calendar and Reminders access in System Settings.

Grove uses the [official Swift MCP SDK](https://github.com/modelcontextprotocol/swift-sdk) and [EventKit](https://developer.apple.com/documentation/eventkit). macOS continues to manage account sync for iCloud, Google, Exchange, and other configured accounts.

## Build

The Xcode project is the primary development entry point:

```sh
./script/build_and_run.sh doctor
./script/build_and_run.sh --verify

# Open the menu bar app.
./script/build_and_run.sh
```

Build or test directly with Xcode’s command-line tools:

```sh
xcodebuild -project Grove.xcodeproj \
  -scheme Grove \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/GroveDerivedData \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build

swift test
```

Request access before the first MCP connection:

```sh
./script/build_and_run.sh authorize
```

The command requests full Calendar and Reminders access. If macOS does not show a prompt, open System Settings → Privacy & Security → Calendar or Reminders and enable Grove.

## MCP configuration

Grove uses the MCP stdio transport. Enable Calendar or Reminders in the menu bar first. Then point the client at the app executable:

```json
{
  "mcpServers": {
    "grove": {
      "command": "/absolute/path/to/grove/build/GroveDerivedData/Build/Products/Debug/Grove.app/Contents/MacOS/Grove",
      "args": ["--mcp"]
    }
  }
}
```

For a release build, use `Grove.app/Contents/MacOS/Grove`. `Package.swift` remains available for lightweight SwiftPM builds and CI experiments.

The menu bar app owns the local MCP process lifecycle. Each `--mcp` process registers with Grove. Quitting Grove sends those processes a termination signal and removes their leases.

## Date and scheduling rules

- Use `YYYY-MM-DD` for date-only values.
- Use ISO 8601 for timed values, with a time-zone offset when needed.
- Event-list range end dates are exclusive.
- Recurrence supports daily, weekly, monthly, and yearly schedules.
- Weekly schedules accept Sunday=1 through Saturday=7.
- Use either a recurrence end date or an occurrence count.
- Use `this_event` or `future_events` when changing a recurring event.
- Alarm values use an absolute ISO 8601 time or minutes relative to the item start.

Example event input:

```json
{
  "title": "Team standup",
  "startDate": "2026-09-09T09:00:00+05:00",
  "endDate": "2026-09-09T09:30:00+05:00",
  "recurrence": {
    "frequency": "weekly",
    "weekdays": [3],
    "count": 8
  },
  "alarms": [{"relativeMinutes": -10}]
}
```

## Architecture

```text
MCP client ── stdio ──▶ Grove.app/Contents/MacOS/Grove --mcp
                              │ shared service settings
Grove menu bar app ───────────┘
        │ quit: terminate active MCP processes
        ▼
Calendar · Reminders
```

The repository follows the normal Xcode command-line project shape:

```text
Grove.xcodeproj
Grove/
    GroveApp.swift
    GroveMenuView.swift
    GroveService.swift
    GroveSettings.swift
    GroveProcessRegistry.swift
    Models.swift
    EventKitStore.swift
    MCPServer.swift
    Info.plist
GroveTests/
    GroveTests.swift
```

The Xcode target is one menu bar application. The small test target remains SwiftPM-only.

Grove reads current data on demand. It returns compact structured results and sends diagnostics to stderr. It does not keep a second copy of Calendar or Reminders data.

## Commands

```text
Grove                 Open the menu bar app.
Grove --mcp           Start the MCP server over stdio.
Grove authorize      Request Calendar and Reminders access.
Grove doctor         Show local permission and runtime status.
Grove --help         Show usage.
Grove --version      Show the version.
```

## Release

The manual release script builds Apple silicon and Intel-based Mac binaries, creates a universal signed app bundle, notarizes it, staples the ticket, and writes a checksum.

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: ..." \
GROVE_BUILD_NUMBER="2" \
APPLE_ID="..." \
APPLE_TEAM_ID="..." \
NOTARYTOOL_PASSWORD="..." \
./script/package_release.sh
```

The signing certificate and notarization values are required. The script stops when they are missing.

### Updates

Sparkle checks [the appcast](https://thsnkhn.github.io/grove/appcast.xml) automatically
while the menu bar app runs. Checks default to on. Users can turn them off in the
menu bar. An available update changes the menu item to **Update Available…**.
Sparkle asks before installing an update. Headless MCP commands do not
start the updater. SwiftPM builds omit Sparkle to keep the lightweight build small.

The release script signs Sparkle's nested code, notarizes the app, staples its
ticket, recreates the ZIP, and generates a signed appcast. Each release needs a
larger integer `GROVE_BUILD_NUMBER`; the display version must match `Grove.version`.

Grove's EdDSA key is stored in the macOS Keychain under the account
`com.thsnkhn.grove`. Keep a secure backup. Only the public key belongs in this
repository. Local appcast generation uses that account. For CI, set
`SPARKLE_ED_KEY_FILE` to a private key file.

The manual GitHub Release workflow needs these repository secrets:

- `DEVELOPER_ID_CERTIFICATE_BASE64`: the exported Developer ID certificate and private key in base64 P12 format.
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`: the P12 password.
- `DEVELOPER_ID_APPLICATION`: the signing identity name.
- `APPLE_ID`, `APPLE_TEAM_ID`, and `NOTARYTOOL_PASSWORD`: notarization credentials.
- `SPARKLE_PRIVATE_KEY`: the exported Grove EdDSA private key.

Run the Release workflow with the version and build number. It uploads the ZIP,
checksum, and `appcast.xml` to GitHub Releases, then deploys GitHub Pages. Website
deploys also fetch the latest stable release's appcast, so a website edit keeps
the feed current. Until the first signed release, Pages serves an empty feed.

## Contributing

Feature requests and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to propose features and contribute implementation work.

For private vulnerability reports, see [the security policy](.github/SECURITY.md).

## License

Grove is licensed under [GPL-3.0](LICENSE).

## Name

**Grove** /ɡroʊv/ — rhymes with “cove.” A growing collection of native Mac tools.

Grove is an independent project. It is not affiliated with or endorsed by Apple.

## Website

The landing page lives in [`website/`](website/) and deploys to GitHub Pages through
[the Pages workflow](.github/workflows/pages.yml). Enable **GitHub Actions** as the
Pages source in the repository settings once, then pushes to `main` publish the site.
