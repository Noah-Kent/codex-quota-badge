import Foundation

public struct QuotaSnapshot: Equatable {
    public let windows: [QuotaWindow]
    public let updatedAt: Date

    public init(windows: [QuotaWindow], updatedAt: Date) {
        self.windows = windows
        self.updatedAt = updatedAt
    }
}

public enum QuotaAvailability: Equatable {
    case unavailable(reason: String)
    case fresh(snapshot: QuotaSnapshot)
    case stale(snapshot: QuotaSnapshot, lastUpdated: Date)
}
