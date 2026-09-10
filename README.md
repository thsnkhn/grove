# Grove

Grove is a native macOS menu bar app that lets your agent use Apple Calendar
and Reminders through a local MCP server.

Your data stays on your Mac. Grove needs no account, cloud service, or
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
3. Open Grove and enable the services you need.

Grove starts its local MCP server at:

```text
http://127.0.0.1:52718/mcp
```

Grove is independent and is not affiliated with or endorsed by Apple.

## Agent setup

On first launch, Grove finds supported agents and offers their setup action.
Grove currently checks for Codex, Claude Code, Hermes, OpenClaw, Cursor, and
Windsurf.

For other clients, add the endpoint using the client’s MCP settings.

### Hermes

Add this to the Hermes MCP configuration:

```yaml
mcp_servers:
  grove:
    url: http://127.0.0.1:52718/mcp
```

Reload MCP servers in Hermes after saving the file.

### OpenClaw

```sh
openclaw mcp set grove '{"url":"http://127.0.0.1:52718/mcp","transport":"streamable-http"}'
```

### Grove agent skill

Grove installs its skill for supported agents when it starts. It writes to
`~/.agents/skills/grove`, `~/.codex/skills/grove`, and `~/.claude/skills/grove`.

If it is not installed, run:

```sh
npx skills add https://github.com/thsnkhn/grove/tree/main/skills/grove --global
```

Restart the agent after installation. See [AGENTS.md](AGENTS.md) for technical
details and stdio setup.

## More

- [Contributing](CONTRIBUTING.md)
- [Security policy](.github/SECURITY.md)
- [GPL-3.0 license](LICENSE)
