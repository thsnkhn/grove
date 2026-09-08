# Grove

Native Apple tools for AI assistants.

[![CI](https://github.com/thsnkhn/grove/actions/workflows/ci.yml/badge.svg)](https://github.com/thsnkhn/grove/actions/workflows/ci.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![MCP](https://img.shields.io/badge/Protocol-MCP-555555)](https://modelcontextprotocol.io/)
[![License](https://img.shields.io/github/license/thsnkhn/grove)](https://github.com/thsnkhn/grove/blob/main/LICENSE)
[![Early development](https://img.shields.io/badge/Status-early_development-D4A017)](https://github.com/thsnkhn/grove)

Grove is a small macOS menu bar app that lets AI assistants work with Apple
Calendar and Reminders.

It is local-first. Your data stays on your Mac. Grove does not need an account,
a cloud service, or a database.

## What Grove can do

Calendar:

- Find calendars and events.
- Create, update, and delete events.
- Handle all-day events, time zones, repeats, and alarms.

Reminders:

- Find reminder lists and reminders.
- Create, update, complete, reopen, and delete reminders.
- Handle due dates, priority, repeats, and alarms.

Enable Calendar or Reminders from the Grove menu bar panel. More Apple app
integrations will appear as they become available.

## Getting started

Grove requires macOS 14 or later.

When a release is available, download Grove from [GitHub Releases](https://github.com/thsnkhn/grove/releases), open it, and allow Calendar or Reminders access when macOS asks.

Connect Grove to your AI assistant through its MCP setup. Developer and client
setup instructions are in [AGENTS.md](AGENTS.md).

## Privacy

Grove reads and changes Apple data only when an enabled MCP tool is called. It
does not copy your Calendar or Reminders data to another store.

## Contributing

Read the [contribution guide](CONTRIBUTING.md) before opening a pull request.
For security issues, read the [security policy](.github/SECURITY.md).

## License

Grove is licensed under [GPL-3.0](LICENSE).

Grove is an independent project. It is not affiliated with or endorsed by Apple.
