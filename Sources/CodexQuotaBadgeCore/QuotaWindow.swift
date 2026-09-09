import Foundation

public enum QuotaSeverity: Equatable, Sendable {
    case normal
    case warning
    case critical
}

public struct QuotaWindow: Equatable, Identifiable, Sendable {
    public let id: String
    public let duration: TimeInterval
    public let usedPercent: Double
    public let resetsAt: Date

    public init(id: String, duration: TimeInterval, usedPercent: Double, resetsAt: Date) {
        self.id = id
        self.duration = duration
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
    }

    public var remainingPercent: Int {
        max(0, min(100, 100 - Int(usedPercent.rounded())))
    }

    public var remainingFraction: Double {
        Double(remainingPercent) / 100
    }

    public var periodLabel: String {
        duration <= 6 * 60 * 60 ? "5H" : "7D"
    }

    public var severity: QuotaSeverity {
        switch remainingPercent {
        case 0..<10: .critical
        case 10..<25: .warning
        default: .normal
        }
    }
}
