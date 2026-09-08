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

extension QuotaWindow {
    static func fixture(usedPercent: Double) -> QuotaWindow {
        QuotaWindow(id: "codex", duration: 5 * 60 * 60, usedPercent: usedPercent, resetsAt: .distantFuture)
    }
}

let tests: [(String, () throws -> Void)] = [
    ("testFiveHourWindowUses5HLabelAndRemainingPercentage", testFiveHourWindowUses5HLabelAndRemainingPercentage),
    ("testSevenDayWindowUses7DLabel", testSevenDayWindowUses7DLabel),
    ("testSeverityUsesRemainingPercentageThresholds", testSeverityUsesRemainingPercentageThresholds)
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
