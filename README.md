# Grove

Grove is a native macOS menu bar app that lets your agent work with Apple
Calendar and Reminders through a local MCP server.

Your data stays on your Mac. Grove does not need an account, cloud service, or
database.

[Download Grove](https://thsnkhn.github.io/grove/) · [View on GitHub](https://github.com/thsnkhn/grove)

## Available now

- Calendar
- Reminders

## Coming later

More Apple apps, including Notes, Mail, Messages, and Contacts.

## Setup

Grove requires macOS 14 or later.

1. Download Grove from the [Grove website](https://thsnkhn.github.io/grove/).
2. Open the DMG and drag Grove to Applications.
3. Open Grove, enable the integrations you need, and approve macOS access.

Grove starts its local MCP server at:

```text
http://127.0.0.1:52718/mcp
```

For Codex:

```sh
codex mcp add grove --url http://127.0.0.1:52718/mcp
```

### Grove agent skill

Grove includes a skill that helps agents use its Calendar and Reminders tools.
If it is not already installed, run:

```sh
npx skills add https://github.com/thsnkhn/grove/tree/main/skills/grove --global
```

Restart your agent after installation. See [AGENTS.md](AGENTS.md) for other
MCP clients and the stdio setup.

## More

- [Contributing](CONTRIBUTING.md)
- [Security policy](.github/SECURITY.md)
- [GPL-3.0 license](LICENSE)

Grove is independent and is not affiliated with or endorsed by Apple.
