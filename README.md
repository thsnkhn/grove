# Grove

Native Mac tools for AI assistants.

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![Swift 6+](https://img.shields.io/badge/Swift-6%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![MCP](https://img.shields.io/badge/Protocol-MCP-555555)](https://modelcontextprotocol.io/)
[![Early development](https://img.shields.io/badge/Status-early_development-D4A017)](https://github.com/thsnkhn/grove)

Grove will connect AI assistants to native macOS apps through the Model Context Protocol (MCP). It starts with Apple Reminders and Calendar, with more Apple apps planned.

**Status:** Project setup. No server, installation package, or working tools are available yet. The sections below describe the planned implementation.

## Direction

- Build in Swift, using public native APIs where available.
- Run locally on macOS.
- Start with a small set of clear, predictable tools.
- Use the existing app data stores and let macOS manage account sync.
- Add support for more apps when there is a useful, maintainable integration path.

Grove will access data locally. An MCP client may send tool results to its model provider according to its own settings.

## Initial scope

### Reminders

- List reminder lists.
- Find and read reminders.
- Create, update, and delete reminders.
- Complete and reopen reminders.
- Support due dates, notes, and priorities.

### Calendar

- List calendars.
- Read events within a date range.
- Create, update, and delete events.
- Support all-day events and explicit time zones.

Recurrence and alarms will follow the basic workflows. Changes to recurring events must distinguish a single occurrence from future occurrences.

## Architecture

```text
MCP client
    │ stdio
    ▼
Grove · Swift MCP server
    │
    ▼
EventKit
    ├── Reminders
    └── Calendar
```

The planned stack is Swift 6+, Swift Package Manager, the [official Swift MCP SDK](https://github.com/modelcontextprotocol/swift-sdk), and [EventKit](https://developer.apple.com/documentation/eventkit). The initial target is macOS 14 or later.

The MCP layer will validate tool inputs and return structured results. A shared EventKit owner will coordinate access to the native store. Calendar and Reminders will each have a focused implementation. No separate content database is planned for the initial version.

## Permissions and API limits

Grove will require separate macOS permissions for Calendar and Reminders. Setup and diagnostic commands are planned to explain missing access and help users resolve it.

Public EventKit APIs do not expose every feature in Apple's apps. Native Reminders tags, sections, and subtasks are outside the initial scope. Calendar attendee editing is also outside the initial scope. Unsupported features will be documented explicitly.

Future app integrations may need different APIs and permissions.

## Roadmap

- [ ] Set up the Swift package and MCP server over stdio.
- [ ] Add permission setup and diagnostics.
- [ ] Implement Reminders tools.
- [ ] Implement Calendar tools.
- [ ] Verify dates, read-only calendars, errors, and retry behavior.
- [ ] Add recurrence and alarm support.
- [ ] Publish a signed and notarized macOS release with setup instructions.
- [ ] Explore more native Apple app integrations.

## Development

Implementation has not started. Build and contribution instructions will be added with the first working Swift package.

## Name

**Grove** /ɡroʊv/ — rhymes with “cove.” A small collection of trees, and a growing collection of native Mac tools.

---

Grove is an independent project and is not affiliated with or endorsed by Apple.
