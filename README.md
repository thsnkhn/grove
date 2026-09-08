# Grove

Native Mac tools for AI assistants.

[![CI](https://github.com/thsnkhn/grove/actions/workflows/ci.yml/badge.svg)](https://github.com/thsnkhn/grove/actions/workflows/ci.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![Swift 6+](https://img.shields.io/badge/Swift-6%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![MCP](https://img.shields.io/badge/Protocol-MCP-555555)](https://modelcontextprotocol.io/)
[![Early development](https://img.shields.io/badge/Status-early_development-D4A017)](https://github.com/thsnkhn/grove)

Grove is a small, local MCP server for macOS. It gives AI assistants access to Apple Calendar and Reminders through Swift and EventKit. More native Apple app integrations can follow.

Grove runs as one executable. It has no GUI, database, background service, network listener, or polling loop.

## Current status

The first working prototype is available. It supports Calendar and Reminders CRUD, common repeat schedules, time alarms, date filters, and local stdio MCP transport.

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

The initial interface has 12 explicit tools. It does not include Calendar-list creation, Reminder-list creation, attendees, location alarms, native Reminders tags, sections, subtasks, or batch operations.

## Requirements

- macOS 14 or later.
- Swift 6 or later for source builds.
- Calendar and Reminders access in System Settings.

Grove uses the [official Swift MCP SDK](https://github.com/modelcontextprotocol/swift-sdk) and [EventKit](https://developer.apple.com/documentation/eventkit). macOS continues to manage account sync for iCloud, Google, Exchange, and other configured accounts.

## Build

```sh
swift build
swift test
```

Run the local executable:

```sh
./script/build_and_run.sh doctor
./script/build_and_run.sh --help
```

Request access before the first MCP connection:

```sh
./.build/arm64-apple-macosx/debug/grove authorize
```

The command requests full Calendar and Reminders access. If macOS does not show a prompt, open System Settings → Privacy & Security → Calendar or Reminders and enable Grove.

## MCP configuration

Grove uses the MCP stdio transport. Point the client at the built executable:

```json
{
  "mcpServers": {
    "grove": {
      "command": "/absolute/path/to/grove/.build/arm64-apple-macosx/debug/grove"
    }
  }
}
```

For a release build, use the executable inside the signed `Grove.app` bundle.

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
MCP client
    │ stdio
    ▼
Grove · Swift executable
    │ one EventKit store
    ▼
Calendar · Reminders
```

Grove reads current data on demand. It returns compact structured results and sends diagnostics to stderr. It does not keep a second copy of Calendar or Reminders data.

## Commands

```text
grove                 Start the MCP server over stdio.
grove authorize       Request Calendar and Reminders access.
grove doctor          Show local permission and runtime status.
grove --help          Show usage.
grove --version       Show the version.
```

## Release

The manual release script builds Apple Silicon and Intel binaries, creates a universal signed app bundle, notarizes it, staples the ticket, and writes a checksum.

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: ..." \
APPLE_ID="..." \
APPLE_TEAM_ID="..." \
NOTARYTOOL_PASSWORD="..." \
./script/package_release.sh
```

The signing certificate and notarization values are required. The script stops when they are missing.

## Name

**Grove** /ɡroʊv/ — rhymes with “cove.” A growing collection of native Mac tools.

Grove is an independent project. It is not affiliated with or endorsed by Apple.

## Website

The landing page lives in [`website/`](website/) and deploys to GitHub Pages through
[the Pages workflow](.github/workflows/pages.yml). Enable **GitHub Actions** as the
Pages source in the repository settings once, then pushes to `main` publish the site.
