# Codex Quota Badge

A local-only macOS menu-bar companion for Codex quota snapshots.

## Privacy and disk behavior

V1 reads only local Codex session data. It does not send network requests, store credentials, read browser cookies, alter Codex files, or keep a usage history. The watcher sleeps between filesystem events and retains only the latest valid snapshot in memory.

## Requirements

- macOS 13 or later
- Swift 6 command-line tools
- At least one local Codex session containing quota data

## Current limitations

The first release is intentionally local-only. Notifications, login, account switching, credit management, and automatic updates are not included.

## Verify

```bash
swift run CodexQuotaBadgeTestRunner
```

## Run locally

```bash
bash scripts/run-local.sh
```

The app appears as `⌁ 配额` in the menu bar. Click it to show the two-row badge. If no local Codex quota snapshot is available, it shows a neutral unavailable state; it does not crash or request access to unrelated folders.

Quit the process with `Control-C` when started from Terminal. V1 does not install itself to Applications, add a login item, or request notification permissions.
