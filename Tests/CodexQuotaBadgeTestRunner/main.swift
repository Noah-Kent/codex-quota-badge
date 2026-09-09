import Foundation
import CodexQuotaBadgeCore

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) throws {
    guard actual == expected else {
        throw TestFailure(description: "\(name): expected \(expected), got \(actual)")
    }
}

func testFiveHourWindowUses5HLabelAndRemainingPercentage() throws {
    let window = QuotaWindow(
        id: "codex",
        duration: 5 * 60 * 60,
        usedPercent: 48,
        resetsAt: .distantFuture
    )

    try expectEqual(window.periodLabel, "5H", "five-hour label")
    try expectEqual(window.remainingPercent, 52, "five-hour remaining percentage")
}

func testSevenDayWindowUses7DLabel() throws {
    let window = QuotaWindow(
        id: "codex",
        duration: 7 * 24 * 60 * 60,
        usedPercent: 8,
        resetsAt: .distantFuture
    )

    try expectEqual(window.periodLabel, "7D", "seven-day label")
    try expectEqual(window.remainingPercent, 92, "seven-day remaining percentage")
}

func testSeverityUsesRemainingPercentageThresholds() throws {
    try expectEqual(QuotaWindow.fixture(usedPercent: 75).severity, .normal, "normal threshold")
    try expectEqual(QuotaWindow.fixture(usedPercent: 80).severity, .warning, "warning threshold")
    try expectEqual(QuotaWindow.fixture(usedPercent: 91).severity, .critical, "critical threshold")
}

func testParserUsesTwoWindowRateLimitRecord() throws {
    let source = try String(contentsOfFile: "Tests/CodexQuotaBadgeTestRunner/Fixtures/valid-two-window.jsonl")
    let snapshot = try unwrap(RateLimitLogParser().latestSnapshot(in: source, now: .distantPast), "two-window snapshot")
    try expectEqual(snapshot.windows.map(\.periodLabel), ["5H", "7D"], "two-window labels")
    try expectEqual(snapshot.windows.map(\.remainingPercent), [52, 92], "two-window remaining values")
}

func testParserIgnoresIncompleteTrailingLine() throws {
    let source = try String(contentsOfFile: "Tests/CodexQuotaBadgeTestRunner/Fixtures/incomplete-line.jsonl")
    let snapshot = try unwrap(RateLimitLogParser().latestSnapshot(in: source, now: .distantPast), "valid line before partial input")
    try expectEqual(snapshot.windows.count, 1, "partial trailing line ignored")
}

func testParserUsesDesktopSnakeCaseRateLimitRecord() throws {
    let source = try String(contentsOfFile: "Tests/CodexQuotaBadgeTestRunner/Fixtures/desktop-rate-limits.jsonl")
    let snapshot = try unwrap(RateLimitLogParser().latestSnapshot(in: source, now: .distantPast), "desktop rate-limit snapshot")
    try expectEqual(snapshot.windows.map(\.periodLabel), ["5H", "7D"], "desktop rate-limit labels")
    try expectEqual(snapshot.windows.map(\.remainingPercent), [60, 16], "desktop rate-limit remaining values")
}

func testMenuBarSummaryUsesBothQuotaWindows() throws {
    let snapshot = QuotaSnapshot(
        windows: [
            QuotaWindow(id: "primary", duration: 5 * 60 * 60, usedPercent: 48, resetsAt: .distantFuture),
            QuotaWindow(id: "secondary", duration: 7 * 24 * 60 * 60, usedPercent: 8, resetsAt: .distantFuture)
        ],
        updatedAt: .distantPast
    )

    try expectEqual(MenuBarSummaryFormatter.text(for: snapshot), "5H 52% ｜ 7D 92%", "single-line summary")
}

func testMenuBarSummaryUsesUnavailableTextWhenNoSnapshotExists() throws {
    try expectEqual(MenuBarSummaryFormatter.text(for: nil), "未检测到配额", "unavailable menu-bar text")
}

func testCompactMenuBarRowsPutPeriodBeforePercentage() throws {
    let snapshot = QuotaSnapshot(
        windows: [
            QuotaWindow(id: "primary", duration: 5 * 60 * 60, usedPercent: 47, resetsAt: .distantFuture),
            QuotaWindow(id: "secondary", duration: 7 * 24 * 60 * 60, usedPercent: 24, resetsAt: .distantFuture)
        ],
        updatedAt: .distantPast
    )

    try expectEqual(MenuBarSummaryFormatter.compactRows(for: snapshot), ["5H 53%", "7D 76%"], "compact menu-bar rows")
}

func testLastUpdatedTimeIncludesSecondsForRefreshFeedback() throws {
    let originalTimeZone = NSTimeZone.default
    NSTimeZone.default = TimeZone(secondsFromGMT: 8 * 60 * 60)!
    defer { NSTimeZone.default = originalTimeZone }

    try expectEqual(
        LastUpdatedFormatter.text(Date(timeIntervalSince1970: 45_296)),
        "20:34:56",
        "last-updated time uses the Mac time zone and includes seconds"
    )
}

func testRefreshDecisionReusesSnapshotWhenTrackedLogIsUnchanged() throws {
    let date = Date(timeIntervalSince1970: 1_000)
    try expectEqual(
        LogRefreshDecision.choose(directoryChanged: false, trackedFileExists: true, cachedModificationDate: date, currentModificationDate: date),
        .reuseCachedSnapshot,
        "unchanged tracked log"
    )
}

func testRefreshDecisionRescansWhenDirectoryChanges() throws {
    let date = Date(timeIntervalSince1970: 1_000)
    try expectEqual(
        LogRefreshDecision.choose(directoryChanged: true, trackedFileExists: true, cachedModificationDate: date, currentModificationDate: date),
        .rescanDirectory,
        "directory event"
    )
}

func testRefreshDecisionParsesOnlyTrackedLogWhenItChanges() throws {
    try expectEqual(
        LogRefreshDecision.choose(directoryChanged: false, trackedFileExists: true, cachedModificationDate: Date(timeIntervalSince1970: 1_000), currentModificationDate: Date(timeIntervalSince1970: 1_001)),
        .parseTrackedFile,
        "changed tracked log"
    )
}

func unwrap<T>(_ value: T?, _ name: String) throws -> T {
    guard let value else { throw TestFailure(description: "\(name): expected a value") }
    return value
}

extension QuotaWindow {
    static func fixture(usedPercent: Double) -> QuotaWindow {
        QuotaWindow(id: "codex", duration: 5 * 60 * 60, usedPercent: usedPercent, resetsAt: .distantFuture)
    }
}

let tests: [(String, () throws -> Void)] = [
    ("testFiveHourWindowUses5HLabelAndRemainingPercentage", testFiveHourWindowUses5HLabelAndRemainingPercentage),
    ("testSevenDayWindowUses7DLabel", testSevenDayWindowUses7DLabel),
    ("testSeverityUsesRemainingPercentageThresholds", testSeverityUsesRemainingPercentageThresholds)
    , ("testParserUsesTwoWindowRateLimitRecord", testParserUsesTwoWindowRateLimitRecord)
    , ("testParserIgnoresIncompleteTrailingLine", testParserIgnoresIncompleteTrailingLine)
    , ("testParserUsesDesktopSnakeCaseRateLimitRecord", testParserUsesDesktopSnakeCaseRateLimitRecord)
    , ("testMenuBarSummaryUsesBothQuotaWindows", testMenuBarSummaryUsesBothQuotaWindows)
    , ("testMenuBarSummaryUsesUnavailableTextWhenNoSnapshotExists", testMenuBarSummaryUsesUnavailableTextWhenNoSnapshotExists)
    , ("testCompactMenuBarRowsPutPeriodBeforePercentage", testCompactMenuBarRowsPutPeriodBeforePercentage)
    , ("testLastUpdatedTimeIncludesSecondsForRefreshFeedback", testLastUpdatedTimeIncludesSecondsForRefreshFeedback)
    , ("testRefreshDecisionReusesSnapshotWhenTrackedLogIsUnchanged", testRefreshDecisionReusesSnapshotWhenTrackedLogIsUnchanged)
    , ("testRefreshDecisionRescansWhenDirectoryChanges", testRefreshDecisionRescansWhenDirectoryChanges)
    , ("testRefreshDecisionParsesOnlyTrackedLogWhenItChanges", testRefreshDecisionParsesOnlyTrackedLogWhenItChanges)
]

do {
    for (name, test) in tests {
        try test()
        print("PASS \(name)")
    }
} catch {
    fputs("FAIL \(error)\n", stderr)
    exit(1)
}
