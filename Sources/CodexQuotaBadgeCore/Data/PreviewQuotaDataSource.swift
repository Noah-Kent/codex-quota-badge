import Foundation

/// Supplies fixed, clearly non-account data for local interface previews only.
public final class PreviewQuotaDataSource: QuotaDataSource {
    private let snapshot: QuotaSnapshot
    private var callback: (@Sendable (Result<QuotaSnapshot?, QuotaDataSourceError>) -> Void)?

    public init(now: Date = Date()) {
        snapshot = QuotaSnapshot(
            windows: [
                QuotaWindow(id: "primary", duration: 5 * 60 * 60, usedPercent: 48, resetsAt: now.addingTimeInterval(2 * 60 * 60 + 18 * 60)),
                QuotaWindow(id: "secondary", duration: 7 * 24 * 60 * 60, usedPercent: 8, resetsAt: now.addingTimeInterval(4 * 24 * 60 * 60 + 12 * 60 * 60))
            ],
            updatedAt: now
        )
    }

    public func start(onUpdate: @escaping @Sendable (Result<QuotaSnapshot?, QuotaDataSourceError>) -> Void) {
        callback = onUpdate
        onUpdate(.success(snapshot))
    }

    public func refreshNow() { callback?(.success(snapshot)) }
    public func stop() { callback = nil }
}
