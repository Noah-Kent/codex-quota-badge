# Codex Quota Badge — Design

## Purpose

Build a small macOS menu-bar companion that keeps Codex quota visible without opening the ChatGPT/Codex app. Its always-on display is a compact two-row badge placed below its menu-bar item.

The product is deliberately narrow: it shows the current rate-limit windows, their remaining percentage, and their reset countdowns. It must stay harmless when Codex is not installed, is not running, has no local data, or changes its local data format.

## Display

The fixed two-row badge uses aligned columns:

```
5H   52%       ↻ 2:13
7D   92%       ↻ 6d 12h
```

- `5H` and `7D` are equal-width period labels.
- The percent and countdown columns use tabular numerals so refreshes do not move the layout.
- Green is normal, orange is below 25% remaining, and red is below 10% remaining.
- Clicking the menu-bar item opens a detail panel with absolute reset times, last update time, data-source state, and a manual refresh action.

## Data and performance

V1 reads only locally available Codex quota snapshots. It watches the narrowly scoped Codex session/log locations through file-system events, debounces bursts of changes, and parses only changed or newly appended data. It does not perform a periodic full-directory scan, send account data to a server, modify Codex files, or retain an activity history.

The process is idle between file-system events. It keeps one in-memory last-valid snapshot and writes only ordinary user preferences (for example, launch-at-login) when a setting changes. This makes CPU, memory, disk reads, and SSD writes negligible in normal use.

The parser is isolated behind a `QuotaDataSource` interface so a future provider can use the local Codex App Server rate-limit method without touching the UI or state rules.

## Resilience rules

| Situation | Result |
| --- | --- |
| Fresh valid snapshot | Show both available windows and live countdowns. |
| Codex is closed | Retain the last valid snapshot, dim it after a freshness threshold, and label the exact last-update time in details. |
| Codex not installed or never used | Show a neutral unavailable state; explain that a Codex conversation must exist before local data can appear. |
| Log is incomplete, malformed, or changed by an update | Preserve the last valid snapshot and retry later without alerting repeatedly. |
| Only one rate-limit window is provided | Display one row; never invent a second window. |
| Offline | Continue to display local data. |
| File access is denied | Show unavailable state and a concise remediation message; do not request broad disk access. |

## Notifications (optional V1.1)

The default release does not notify. A later opt-in setting may send a macOS notification only after a rate-limit reset is confirmed by a new valid snapshot or an available Codex App Server `rateLimits/updated` event. It must never notify merely because the predicted reset time elapsed.

When supported, active official workspace messages may be shown separately in the detail panel. They are not required for quota monitoring and never block it.

## Technical shape

- Native SwiftUI macOS application with an `NSStatusItem` anchor and a non-activating `NSPanel` badge.
- `QuotaDataSource`: discovers and validates local data.
- `QuotaStore`: owns the last-valid snapshot, freshness, availability, and countdown timer.
- `BadgeView` and `DetailPopover`: pure presentation.
- `FileWatcher`: event-driven, debounced local watching.
- Parser fixtures cover valid, missing, partial, malformed, changed-format, single-window, and stale snapshots.

## Acceptance criteria

1. The two rows remain visually aligned as values and countdown digits change.
2. With no Codex data, the app launches successfully and shows a calm unavailable state.
3. With unreadable or malformed input, the app keeps the last valid reading and does not crash.
4. In idle conditions, the app does no repeated full log scan and performs no recurring app-owned disk writes.
5. The app neither stores credentials nor makes any network request in V1.
6. V1 can be closed and relaunched without touching Codex configuration or session files.

## Deliberately out of scope for V1

- ChatGPT/Codex login, account switching, API keys, or browser cookies.
- Purchased-credit management or quota resets.
- Cost estimates, reports, themes, multiple AI-provider support, and automatic updates.
- Notifications, except the reserved design hook described above.
