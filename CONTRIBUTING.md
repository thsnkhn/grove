# Contributing to Grove

Grove accepts contributions.

This project is a native macOS menu bar app and local MCP server. Contributions are welcome in two main forms:

- feature requests for new Apple app integrations or better assistant workflows
- pull requests that implement open issues or improve existing behavior

## Feature Requests

Feature requests are welcome, especially when they describe a real assistant workflow.

Good feature requests usually include:

- the problem you are trying to solve
- how you expect Grove to behave
- the Apple app or framework involved, if known
- examples and edge cases that contributors should consider

Small, focused requests are easier to discuss and build. A large idea may be split into smaller implementation issues before work starts.

## Working on Features

If you want to work on a feature, start with an open issue.

Before opening a pull request:

- comment on the issue so others know you are working on it
- keep the first implementation scoped to the issue
- ask questions on the issue if behavior is unclear
- prefer native macOS patterns over web-style UI patterns
- keep integrations local and avoid cloud services, accounts, or hosted dependencies unless the issue calls for them

Pull requests that implement features proposed by other contributors are welcome. You do not need to be the person who opened the issue.

## Pull Requests

When opening a pull request, include:

- what changed
- which issue it closes or relates to
- how you tested it
- screenshots or screen recordings for changes to the menu bar UI
- the AI tool and model you used, if AI assisted with the contribution, and a short description of how you used it

You remain responsible for the code, tests, documentation, and review of an AI-assisted contribution.

Keep pull requests focused. A small pull request that solves one clear issue is easier to review than a large pull request that mixes unrelated changes.

## Code Style

Grove is built with Swift, SwiftUI, AppKit, EventKit, and the Swift Package Manager.

Please follow the existing project style:

- keep menu bar UI, preferences, process lifecycle, EventKit access, and MCP transport separated
- prefer clear names over clever abstractions
- add defensive code only for a verified failure mode, platform constraint, or data-safety requirement
- avoid speculative fallback layers that make the code harder to read and maintain
- keep user-facing behavior predictable and conservative
- use native macOS controls and platform conventions where possible
- preserve Grove's local-first and privacy-friendly product direction
- do not add a database, network listener, or second copy of Calendar or Reminders data without a clear issue

## Bugs

Bug reports are welcome. Include the Grove version or commit, macOS version, steps to reproduce, expected behavior, and actual behavior. If the report involves an MCP client, include its name and version. Remove personal Calendar or Reminders data from logs and screenshots.

Do not open a public issue for a security vulnerability. See [.github/SECURITY.md](.github/SECURITY.md).

## License

By contributing to Grove, you agree that your contribution will be licensed under the same license as the project.
