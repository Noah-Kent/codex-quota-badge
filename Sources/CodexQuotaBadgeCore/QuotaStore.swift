import Foundation
import Combine

@MainActor
public final class QuotaStore: ObservableObject {
    @Published public private(set) var availability: QuotaAvailability = .unavailable(reason: "尚未发现 Codex 配额数据")
    @Published public private(set) var now = Date()
    private let source: QuotaDataSource
    private var lastValid: QuotaSnapshot?
    private var timer: Timer?

    public init(source: QuotaDataSource) { self.source = source }

    public func start() {
        source.start { [weak self] result in
            Task { @MainActor in self?.apply(result) }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
    }

    public func refresh() { source.refreshNow() }
    public func stop() { timer?.invalidate(); source.stop() }

    private func apply(_ result: Result<QuotaSnapshot?, QuotaDataSourceError>) {
        switch result {
        case .success(.some(let snapshot)):
            lastValid = snapshot; availability = .fresh(snapshot: snapshot)
        case .success(.none):
            availability = lastValid.map { .stale(snapshot: $0, lastUpdated: $0.updatedAt) } ?? .unavailable(reason: "尚未发现 Codex 配额数据")
        case .failure:
            availability = lastValid.map { .stale(snapshot: $0, lastUpdated: $0.updatedAt) } ?? .unavailable(reason: "暂时无法读取 Codex 配额数据")
        }
    }
}
