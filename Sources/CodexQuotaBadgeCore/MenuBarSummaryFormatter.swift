import Foundation

public enum MenuBarSummaryFormatter {
    public static func text(for snapshot: QuotaSnapshot?) -> String {
        guard let snapshot else { return "未检测到配额" }
        let windows = snapshot.windows.sorted { $0.duration < $1.duration }
        guard windows.count >= 2 else { return "未检测到配额" }
        return windows.prefix(2)
            .map { "\($0.periodLabel) \($0.remainingPercent)%" }
            .joined(separator: " ｜ ")
    }

    public static func compactRows(for snapshot: QuotaSnapshot?) -> [String] {
        guard let snapshot else { return [] }
        let windows = snapshot.windows.sorted { $0.duration < $1.duration }
        guard windows.count >= 2 else { return [] }
        return windows.prefix(2).map { "\($0.periodLabel) \($0.remainingPercent)%" }
    }
}
