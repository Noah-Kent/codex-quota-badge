import Foundation

public enum QuotaDataSourceError: Error, Equatable, Sendable {
    case unreadable
}

public protocol QuotaDataSource: AnyObject {
    func start(onUpdate: @escaping @Sendable (Result<QuotaSnapshot?, QuotaDataSourceError>) -> Void)
    func refreshNow()
    func stop()
}
