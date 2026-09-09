# Codex Quota Badge

[简体中文](README.md) | [English](README.en.md)

A quiet, lightweight macOS menu-bar app for checking your remaining Codex 5-hour and 7-day quota.

**Local and read-only · No credential access · No network requests · No telemetry**

<p align="center">
  <img src="assets/app-icon/AppIcon-source.png" width="128" alt="Codex Quota Badge icon">
</p>

```text
5H 52%
7D 92%
```

Click the menu-bar quota to see colored progress bars, reset times, and the last update:

![Codex Quota Badge detail panel](assets/screenshots/detail-preview.png)

Codex Quota Badge does one job: it keeps the quota information you check most often in the menu bar, so you do not have to keep opening a usage page.

> This is an open-source preview. Release `.dmg` files use ad-hoc signing and are not Apple-notarized. A macOS security prompt means that the system cannot verify the publisher identity; it **does not mean** macOS has determined that this project is malicious or unsafe. Always download from this repository and review the source yourself.

## Features

- Compact two-line display for remaining `5H` and `7D` quota.
- A colored progress bar, reset times, and last-update time available on click.
- **Refresh now**, **Hide details**, and **Quit** controls.
- A borderless detail panel that can be dragged outside the button area.
- A calm **No quota detected** state when no usable snapshot exists.
- Keeps the latest valid snapshot if a log is temporarily unreadable or ends with an incomplete line.
- A native macOS app icon and no Dock presence.

## Install and run

### Install the preview package

Download the preview `.dmg` from [GitHub Releases](../../releases/latest), open it, and drag the app into **Applications**.

The preview package is not Developer ID-signed or Apple-notarized, so macOS may block its first launch or display a warning such as an unverified developer notice. This indicates that Apple has not verified the **publisher identity**; it is not a security verdict about the software. Confirm that the file came from this repository, and do not disable Gatekeeper or weaken system-wide security settings just to install it.

If you prefer not to handle download security prompts, build from source on your own Mac. A locally built copy does not carry the internet-download quarantine flag and will normally avoid this prompt.

### Run from source

Requirements:

- macOS 13 or later;
- Swift 6 command-line tools;
- at least one Codex session that has produced a local quota snapshot.

Clone the repository, enter its directory, and run:

```bash
bash scripts/run-local.sh
```

Or run it manually:

```bash
swift build
swift run CodexQuotaBadge
```

To build local preview `.app` and `.dmg` files:

```bash
bash scripts/create-preview-dmg.sh
```

Artifacts are written to `dist/`.

## Privacy and security

The app reads existing Codex session logs under `~/.codex/sessions` on the current Mac only to locate quota snapshot fields. It does not:

- read browser cookies, passwords, tokens, or API keys;
- modify or delete Codex logs;
- save, upload, or forward conversation content;
- send requests to OpenAI or third-party servers;
- create a quota-history database or upload telemetry;
- sign in, purchase credits, or perform account actions.

Parsing happens in local memory. The cached quota snapshot disappears with the process when the app quits.

Here, “safe” means minimal permissions, local read-only access, no network transfer, and no interference with Codex. No software should claim absolute zero risk. If local log access concerns you, inspect the source before running it.

Never attach a complete session log to an issue. Share only a minimal, redacted sample with conversation content, real paths, and account information removed.

## Why it is lightweight

The app does not rescan every log once a minute:

```text
Launch → find the newest valid log and cache its quota snapshot
                         ↓
Each minute, check only the tracked file's state
 ├─ unchanged → reuse the in-memory snapshot
 ├─ changed   → read and parse small chunks from the tracked file's tail
 └─ new session or deletion → rediscover a valid log
```

macOS filesystem events report directory changes. The app has no periodic writes, database, history store, or background network traffic.

Two idle samples of a Release build on the development Mac measured `0.0%` CPU and about `56.8 MiB` RSS. This is a short measurement on one machine, not a guarantee for every Mac. See [performance methodology](docs/PERFORMANCE.md) for the method and disk-I/O boundaries.

## FAQ

### Why does it say “No quota detected”?

There may not be a local Codex session containing a quota snapshot yet. The app will not request a login or fall back to browser or account credentials. Run a Codex session, then choose **Refresh now**.

### Must ChatGPT or Codex remain open?

No. The app can continue showing the latest valid snapshot. Values change only after Codex writes a newer local quota snapshot.

### Why can the value differ from the web page?

The app reads the most recently written local snapshot, not an official public real-time quota API, so it may temporarily lag behind the web UI.

### What if a Codex update changes the log format?

The local log format is an implementation detail and may change. Open an issue with a minimal, redacted format sample.

### How do I quit or uninstall it?

Choose **Quit** in the detail panel. The app installs no login item, background service, or quota-history database. Remove it from **Applications** to uninstall it.

### Why is the menu-bar item missing?

First confirm that the app is running. A crowded menu bar or a third-party menu-bar manager may also hide menu-bar items.

## Tests

```bash
swift run CodexQuotaBadgeTestRunner
```

Tests cover quota-window recognition, remaining percentages, desktop log format, incomplete final lines, menu-bar text, local time, cache reuse, and refresh decisions.

## Current limitations

- macOS 13 or later only.
- Tested on Apple Silicon; Intel Mac has not been manually verified.
- Quota comes from local Codex logs, so parser updates may be needed if their format changes.
- No sign-in, account switching, credit purchase, notifications, or automatic updates.
- The current Release is an ad-hoc-signed, non-notarized preview. A security prompt means the publisher identity is unverified, not that the app is deemed malicious; users who prefer to avoid the prompt can build from source.

## Project structure

```text
Sources/CodexQuotaBadge/          macOS menu-bar UI
Sources/CodexQuotaBadgeCore/      Log parsing, cache, and quota state
Tests/CodexQuotaBadgeTestRunner/  Test runner and redacted fixtures
Packaging/                        App metadata and icon
assets/                           README screenshots and icon source
scripts/                          Local run, build, and package scripts
docs/                             Design, plans, performance, and status
```

## Contributing

Issues and pull requests are welcome, especially for new log formats, edge cases, macOS accessibility, and release workflow improvements.

## License

This project is licensed under the [MIT License](LICENSE). You may use, copy, modify, and distribute it, including commercially, as long as the copyright and license notice are retained.

## Disclaimer

This is an unofficial community project. It is not affiliated with or endorsed by OpenAI. Codex, ChatGPT, and OpenAI are trademarks of their respective owners. The app relies on local implementation details that may change in a future update.
