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
