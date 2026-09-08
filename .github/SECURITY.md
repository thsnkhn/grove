# Security Policy

Grove is a local-only macOS menu bar app and stdio MCP server. It accesses Calendar and Reminders through EventKit. It does not run a network listener or send Calendar or Reminders data to a hosted backend.

The menu bar app uses Sparkle to check an architecture-specific HTTPS appcast on
GitHub Pages and download updates from GitHub Releases. Update archives must
pass EdDSA signature verification. The release workflow also signs and
notarizes the app with Apple.
Report update-signature bypasses through the same private reporting flow below.

## Supported Versions

Security fixes are prioritized for the latest stable Grove release and the current main branch.

| Version | Supported |
| --- | --- |
| Latest stable release | Yes |
| Current main branch | Yes |
| Older releases | No |

## Reporting a Vulnerability

Please do not open a public issue for security vulnerabilities.

Use GitHub's private vulnerability reporting flow from the repository Security tab:

1. Open the Grove repository on GitHub.
2. Go to **Security**.
3. Choose **Report a vulnerability**.

Include as much detail as you can safely share:

- affected Grove version or commit
- macOS version and architecture
- MCP client name and version, if involved
- enabled Grove service, such as Calendar or Reminders
- steps to reproduce
- expected and actual behavior
- logs, screenshots, or sample MCP input and output if they do not contain personal data

I will acknowledge valid private reports as soon as practical, triage the impact, and coordinate a fix before public disclosure when appropriate.
