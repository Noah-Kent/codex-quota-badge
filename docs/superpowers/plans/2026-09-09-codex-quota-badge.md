# Codex Quota Badge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu-bar app that passively displays locally available Codex quota windows, remaining percentages, and reset countdowns in a resilient two-row badge.

**Architecture:** A Swift Package executable owns the AppKit lifecycle. `LocalLogQuotaDataSource` discovers and incrementally parses only Codex log updates while `QuotaStore` turns validated snapshots into UI state and formatted countdowns. A non-activating AppKit panel renders a SwiftUI two-row badge below an `NSStatusItem`; missing, stale, and malformed data stay contained in the source/store layer.

**Tech Stack:** Swift 6.3, Swift Package Manager, AppKit, SwiftUI, Foundation, XCTest.

**Spec:** `docs/superpowers/specs/2026-09-09-codex-quota-badge-design.md`

## Global Constraints

- Target macOS 13+ and use only Apple system frameworks in V1.
- V1 is strictly local: no network request, account credential, browser cookie, API key, login flow, automatic update, quota reset, cost estimate, or notification.
- Watch only explicitly discovered Codex session/log roots; do not request broad disk permissions.
- Prefer filesystem events plus a debounced refresh over timer-driven directory scans.
- Keep the last valid snapshot only in memory; persist only explicit user preferences.
- Never modify Codex files or configuration.
- Show only backend-provided windows; do not invent a missing 5-hour or weekly row.
- `5H` and `7D` labels must be equal-width, all numeric text must use tabular figures, and colors are green at 25%+, orange at 10–24%, red below 10%.

---

## File structure

```text
Package.swift                                  SwiftPM package definition
Sources/CodexQuotaBadge/App/main.swift         NSApplication lifecycle and app composition
Sources/CodexQuotaBadge/Domain/QuotaWindow.swift
                                                Validated quota value and display semantics
Sources/CodexQuotaBadge/Domain/QuotaSnapshot.swift
                                                Full source snapshot and availability state
Sources/CodexQuotaBadge/Data/QuotaDataSource.swift
                                                Data-source protocol and event callbacks
Sources/CodexQuotaBadge/Data/LocalLogQuotaDataSource.swift
                                                Scoped discovery, append-aware parsing, debounce
Sources/CodexQuotaBadge/Data/RateLimitLogParser.swift
                                                JSONL extraction and validation boundary
Sources/CodexQuotaBadge/State/QuotaStore.swift Source state, freshness, and countdown refresh
Sources/CodexQuotaBadge/UI/QuotaBadgePanel.swift
                                                NSStatusItem + non-activating panel positioning
Sources/CodexQuotaBadge/UI/QuotaBadgeView.swift
                                                Two-row aligned SwiftUI badge
Sources/CodexQuotaBadge/UI/QuotaDetailView.swift
                                                Click detail view and unavailable/stale copy
Tests/CodexQuotaBadgeTests/RateLimitLogParserTests.swift
Tests/CodexQuotaBadgeTests/QuotaStoreTests.swift
Tests/CodexQuotaBadgeTests/QuotaWindowTests.swift
Tests/CodexQuotaBadgeTests/Fixtures/*.jsonl    Controlled valid and invalid local log inputs
README.md                                       Build, local-only privacy, and troubleshooting
scripts/run-local.sh                            Debug launch script; never installs or copies files
```

### Task 1: Create a buildable, testable native app shell

**Files:**
- Create: `Package.swift`
- Create: `Sources/CodexQuotaBadge/App/main.swift`
- Create: `Sources/CodexQuotaBadge/Domain/QuotaWindow.swift`
- Create: `Sources/CodexQuotaBadge/Domain/QuotaSnapshot.swift`
- Create: `Tests/CodexQuotaBadgeTests/QuotaWindowTests.swift`
- Create: `README.md`

**Interfaces:**
- Produces `QuotaWindow`, `QuotaSnapshot`, and `QuotaAvailability` for all later tasks.
- `QuotaWindow` initializer: `init(id: String, duration: TimeInterval, usedPercent: Double, resetsAt: Date)`.
- `QuotaWindow.remainingPercent: Int`, `QuotaWindow.periodLabel: String`, and `QuotaWindow.severity: QuotaSeverity` are used by the store and UI.

- [ ] **Step 1: Write the failing domain tests**

```swift
func testFiveHourWindowUses5HLabelAndRemainingPercentage() {
    let window = QuotaWindow(id: "codex", duration: 5 * 60 * 60,
                             usedPercent: 48, resetsAt: .distantFuture)
    XCTAssertEqual(window.periodLabel, "5H")
    XCTAssertEqual(window.remainingPercent, 52)
}

func testSeverityUsesRemainingPercentageThresholds() {
    XCTAssertEqual(QuotaWindow.fixture(usedPercent: 75).severity, .normal)
    XCTAssertEqual(QuotaWindow.fixture(usedPercent: 80).severity, .warning)
    XCTAssertEqual(QuotaWindow.fixture(usedPercent: 91).severity, .critical)
}
```

- [ ] **Step 2: Run the failing tests**

Run: `swift test --filter QuotaWindowTests`

Expected: FAIL because the package and `QuotaWindow` do not exist.

- [ ] **Step 3: Create the package and minimum domain model**

```swift
public enum QuotaSeverity: Equatable { case normal, warning, critical }

public struct QuotaWindow: Equatable, Identifiable {
    public let id: String
    public let duration: TimeInterval
    public let usedPercent: Double
    public let resetsAt: Date

    public var remainingPercent: Int { max(0, min(100, 100 - Int(usedPercent.rounded()))) }
    public var periodLabel: String { duration <= 6 * 3600 ? "5H" : "7D" }
    public var severity: QuotaSeverity {
        switch remainingPercent { case 0..<10: .critical; case 10..<25: .warning; default: .normal }
    }
}
```

Define `QuotaAvailability` as `.unavailable(reason: String)`, `.fresh(snapshot: QuotaSnapshot)`, and `.stale(snapshot: QuotaSnapshot, lastUpdated: Date)`. Keep `main.swift` to a minimal `NSApplication` setup so the executable launches without network or file access.

- [ ] **Step 4: Run all tests and launch smoke test**

Run: `swift test && swift run CodexQuotaBadge`

Expected: tests PASS; app process starts without opening a Dock window or crashing.

- [ ] **Step 5: Document the local-only contract**

Write README sections named `What it does`, `Privacy and disk behavior`, `Requirements`, and `Current limitations`. State plainly that V1 does not send network traffic, handle credentials, or modify Codex data.

- [ ] **Step 6: Commit the shell**

```bash
git add Package.swift Sources Tests README.md
git commit -m "feat: scaffold native quota badge"
```

### Task 2: Parse and validate local Codex quota snapshots

**Files:**
- Create: `Sources/CodexQuotaBadge/Data/RateLimitLogParser.swift`
- Create: `Tests/CodexQuotaBadgeTests/RateLimitLogParserTests.swift`
- Create: `Tests/CodexQuotaBadgeTests/Fixtures/valid-two-window.jsonl`
- Create: `Tests/CodexQuotaBadgeTests/Fixtures/valid-one-window.jsonl`
- Create: `Tests/CodexQuotaBadgeTests/Fixtures/malformed-then-valid.jsonl`
- Create: `Tests/CodexQuotaBadgeTests/Fixtures/incomplete-line.jsonl`

**Interfaces:**
- Consumes `QuotaWindow` and `QuotaSnapshot` from Task 1.
- Produces `RateLimitLogParser.latestSnapshot(in: String, now: Date) throws -> QuotaSnapshot?`.
- A parser returns `nil` for no usable rate-limit record and throws `RateLimitLogParserError.invalidPayload` only when a syntactically complete candidate cannot be validated.

- [ ] **Step 1: Add fixture-based failing tests**

```swift
func testParserUsesLastValidTwoWindowRateLimitRecord() throws {
    let source = try fixture("valid-two-window.jsonl")
    let snapshot = try XCTUnwrap(try parser.latestSnapshot(in: source, now: fixedNow))
    XCTAssertEqual(snapshot.windows.map(\.periodLabel), ["5H", "7D"])
    XCTAssertEqual(snapshot.windows.map(\.remainingPercent), [52, 92])
}

func testParserIgnoresIncompleteTrailingLine() throws {
    XCTAssertNoThrow(try parser.latestSnapshot(in: fixture("incomplete-line.jsonl"), now: fixedNow))
}
```

- [ ] **Step 2: Run the parser tests to verify failure**

Run: `swift test --filter RateLimitLogParserTests`

Expected: FAIL because `RateLimitLogParser` does not exist.

- [ ] **Step 3: Implement a narrow JSONL parser**

Read input line-by-line. Decode only JSON objects containing `rateLimits` or `rateLimitsByLimitId`; validate `usedPercent` in `0...100`, positive `windowDurationMins`, and a positive Unix `resetsAt`. Convert durations to seconds and sort rows by duration ascending. Keep the newest fully valid record; skip malformed lines before it and ignore a non-terminated trailing partial line.

```swift
struct RateLimitLogParser {
    func latestSnapshot(in jsonl: String, now: Date) throws -> QuotaSnapshot? {
        // Decode each complete line, retaining the latest fully validated candidate.
    }
}
```

- [ ] **Step 4: Run parser tests and the full suite**

Run: `swift test`

Expected: PASS; a malformed final line never replaces a prior valid snapshot.

- [ ] **Step 5: Commit parser and fixtures**

```bash
git add Sources/CodexQuotaBadge/Data Tests/CodexQuotaBadgeTests
git commit -m "feat: parse local quota snapshots"
```

### Task 3: Add scoped file discovery and event-driven refresh

**Files:**
- Create: `Sources/CodexQuotaBadge/Data/QuotaDataSource.swift`
- Create: `Sources/CodexQuotaBadge/Data/LocalLogQuotaDataSource.swift`
- Create: `Tests/CodexQuotaBadgeTests/LocalLogQuotaDataSourceTests.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes `RateLimitLogParser.latestSnapshot(in:now:)` from Task 2.
- Produces `QuotaDataSource.start(onUpdate:)`, `QuotaDataSource.refreshNow()`, and `QuotaDataSource.stop()`.
- `onUpdate` sends `Result<QuotaSnapshot?, QuotaDataSourceError>`; it never sends raw log contents beyond the data-source boundary.

- [ ] **Step 1: Write discovery and no-data tests using a temporary directory**

```swift
func testNoSessionDirectoryReturnsNoDataWithoutFailure() throws {
    let source = LocalLogQuotaDataSource(root: temporaryDirectory)
    XCTAssertNil(try source.readLatestSnapshot())
}

func testSourceReadsOnlyNewestChangedJSONLFile() throws {
    try writeFixture("valid-one-window.jsonl", named: "newest.jsonl")
    try writeFixture("malformed-then-valid.jsonl", named: "older.jsonl", modified: oldDate)
    XCTAssertEqual(try source.readLatestSnapshot()?.windows.count, 1)
}
```

- [ ] **Step 2: Run the source tests to verify failure**

Run: `swift test --filter LocalLogQuotaDataSourceTests`

Expected: FAIL because `LocalLogQuotaDataSource` does not exist.

- [ ] **Step 3: Implement restricted discovery and debounced watching**

Use only an injected root for tests and the explicitly documented Codex session root in production. Enumerate files with the `.jsonl` extension, ordered by modification date, and stop reading once a current valid snapshot is found. Use `DispatchSource.makeFileSystemObjectSource` on the discovered directory; on `.write`, `.rename`, or `.delete`, schedule exactly one `refreshNow()` on a serial queue after a two-second debounce. Do not use a repeating scan timer.

```swift
protocol QuotaDataSource: AnyObject {
    func start(onUpdate: @escaping (Result<QuotaSnapshot?, QuotaDataSourceError>) -> Void)
    func refreshNow()
    func stop()
}
```

- [ ] **Step 4: Add explicit source-state documentation**

Document the only permitted production root, the no-data behavior, and that no data is copied, uploaded, or written back.

- [ ] **Step 5: Run the source tests and full suite**

Run: `swift test`

Expected: PASS; a missing directory returns no data and no test writes outside its temporary root.

- [ ] **Step 6: Commit the data source**

```bash
git add Sources/CodexQuotaBadge/Data Tests/CodexQuotaBadgeTests README.md
git commit -m "feat: watch local quota data safely"
```

### Task 4: Model freshness, countdowns, and safe fallback states

**Files:**
- Create: `Sources/CodexQuotaBadge/State/QuotaStore.swift`
- Create: `Tests/CodexQuotaBadgeTests/QuotaStoreTests.swift`

**Interfaces:**
- Consumes `QuotaDataSource` from Task 3 and `QuotaAvailability` from Task 1.
- Produces `@MainActor final class QuotaStore: ObservableObject` with `@Published private(set) var availability: QuotaAvailability` and `func refresh()`.
- UI consumes `displayRows: [QuotaDisplayRow]`, `statusMessage: String`, and `lastUpdatedText: String`.

- [ ] **Step 1: Write deterministic store tests with a fake data source and clock**

```swift
func testMalformedRefreshKeepsLastValidSnapshotAsStale() async {
    let source = FakeQuotaDataSource(results: [.success(validSnapshot), .failure(.malformedData)])
    let store = QuotaStore(source: source, now: { fixedNow })
    await store.refresh()
    await store.refresh()
    XCTAssertEqual(store.availability, .stale(snapshot: validSnapshot, lastUpdated: fixedNow))
}

func testUnavailableSourceUsesCalmNoDataMessage() async {
    let store = QuotaStore(source: FakeQuotaDataSource(results: [.success(nil)]), now: { fixedNow })
    await store.refresh()
    XCTAssertEqual(store.statusMessage, "尚未发现 Codex 配额数据")
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter QuotaStoreTests`

Expected: FAIL because `QuotaStore` does not exist.

- [ ] **Step 3: Implement state transitions and countdown-only updates**

Keep the newest valid snapshot in memory. Convert a `nil` result to unavailable only when no valid snapshot has ever existed. Convert a parse or access failure after a valid snapshot to stale. Use one lightweight in-memory one-minute timer only to re-render countdown text from the current reset timestamps; it must never invoke `QuotaDataSource.refreshNow()`.

```swift
@MainActor
final class QuotaStore: ObservableObject {
    @Published private(set) var availability: QuotaAvailability = .unavailable(reason: "尚未发现 Codex 配额数据")
    func refresh() { /* request source; preserve the last valid snapshot on failure */ }
}
```

- [ ] **Step 4: Run all store tests**

Run: `swift test --filter QuotaStoreTests && swift test`

Expected: PASS; countdown refresh does not read from disk, and malformed data does not erase valid data.

- [ ] **Step 5: Commit state management**

```bash
git add Sources/CodexQuotaBadge/State Tests/CodexQuotaBadgeTests
git commit -m "feat: add resilient quota state"
```

### Task 5: Render the aligned menu-bar badge and detail panel

**Files:**
- Create: `Sources/CodexQuotaBadge/UI/QuotaBadgeView.swift`
- Create: `Sources/CodexQuotaBadge/UI/QuotaDetailView.swift`
- Create: `Sources/CodexQuotaBadge/UI/QuotaBadgePanel.swift`
- Modify: `Sources/CodexQuotaBadge/App/main.swift`
- Modify: `Tests/CodexQuotaBadgeTests/QuotaWindowTests.swift`

**Interfaces:**
- Consumes `QuotaStore.displayRows`, `QuotaStore.statusMessage`, and `QuotaStore.lastUpdatedText` from Task 4.
- Produces `QuotaBadgePanel.show()`, `QuotaBadgePanel.hide()`, and `QuotaBadgeView`.

- [ ] **Step 1: Write formatting assertions for UI-facing values**

```swift
func testCountdownFormatsUnderOneDayAsHoursAndMinutes() {
    XCTAssertEqual(QuotaWindow.countdownText(until: fixedNow.addingTimeInterval(7_980), now: fixedNow), "2:13")
}

func testCountdownFormatsOverOneDayAsDaysAndHours() {
    XCTAssertEqual(QuotaWindow.countdownText(until: fixedNow.addingTimeInterval(561_600), now: fixedNow), "6d 12h")
}
```

- [ ] **Step 2: Run the formatting assertions to verify failure**

Run: `swift test --filter QuotaWindowTests`

Expected: FAIL because `countdownText(until:now:)` does not exist.

- [ ] **Step 3: Implement the SwiftUI views and AppKit anchor**

Use a grid with a 34-point label column, 46-point percent column, and trailing countdown column. Apply `.monospacedDigit()` to percentage and countdown text. Map `QuotaSeverity` to green/orange/red. Put the badge in an opaque, rounded non-activating `NSPanel` positioned below a small status-item anchor; clicking the anchor toggles the panel. When unavailable, show a single neutral row with `—` and the calm data-source message. When stale, preserve rows with reduced opacity and show the exact update timestamp in `QuotaDetailView`.

The detail view must include each absolute reset time, last update, source state, and a `Refresh` button calling only `QuotaStore.refresh()`.

- [ ] **Step 4: Wire app composition**

In `main.swift`, construct `LocalLogQuotaDataSource`, `QuotaStore`, and `QuotaBadgePanel`; start source watching after `NSApplication` finishes launching and call `stop()` on termination. Ensure activation policy is `.accessory` so no Dock icon is shown.

- [ ] **Step 5: Run automated tests and manual UI checks**

Run: `swift test && swift run CodexQuotaBadge`

Expected: PASS. Manually confirm the panel shows two aligned rows for fixture data, one row for a single-window fixture, neutral unavailable text without data, and stale values after a forced parser failure.

- [ ] **Step 6: Commit UI**

```bash
git add Sources/CodexQuotaBadge/App Sources/CodexQuotaBadge/UI Sources/CodexQuotaBadge/Domain Tests/CodexQuotaBadgeTests
git commit -m "feat: display quota badge"
```

### Task 6: Add local launch ergonomics and release-readiness checks

**Files:**
- Create: `scripts/run-local.sh`
- Modify: `README.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes the `CodexQuotaBadge` executable from Task 5.
- Produces a local debug launcher only; it must not copy to `/Applications`, install a login item, alter security settings, or create an auto-update process.

- [ ] **Step 1: Write a shell smoke check**

```bash
#!/usr/bin/env bash
set -euo pipefail
swift build
test -x .build/debug/CodexQuotaBadge
```

- [ ] **Step 2: Run the script before it exists**

Run: `bash scripts/run-local.sh`

Expected: FAIL with “No such file or directory”.

- [ ] **Step 3: Implement the debug launcher and final README instructions**

Create the script above and append `exec .build/debug/CodexQuotaBadge`. Document how to launch it, how to quit it, required macOS version, the no-data state, stale-data meaning, and that notifications are intentionally not implemented in V1.

- [ ] **Step 4: Run release-readiness verification**

Run: `swift test && bash scripts/run-local.sh`

Expected: all tests PASS; app launches locally without network activity, application installation, or Codex-file modification.

- [ ] **Step 5: Commit the launch flow**

```bash
git add scripts/run-local.sh README.md .gitignore
git commit -m "docs: add local launch guidance"
```

## Final verification checklist

- [ ] Run `swift test` and capture the complete passing result.
- [ ] Launch with no discovered Codex data and verify unavailable state without a crash.
- [ ] Feed valid two-window, valid one-window, malformed-after-valid, and incomplete JSONL fixtures through the parser.
- [ ] Confirm the running process has no network request code path and never writes inside the discovered Codex data root.
- [ ] Manually verify `5H` / `7D`, percentage, and countdown columns remain aligned as timer text changes.
- [ ] Verify `git status --short` contains no generated build output or brainstorm artifacts.
