import Darwin
import Dispatch
import Foundation

public final class LocalLogQuotaDataSource: QuotaDataSource, @unchecked Sendable {
    private let root: URL
    private let parser: RateLimitLogParser
    private let queue = DispatchQueue(label: "CodexQuotaBadge.LocalLogQuotaDataSource")
    private var watcher: DispatchSourceFileSystemObject?
    private var debounce: DispatchWorkItem?
    private var callback: (@Sendable (Result<QuotaSnapshot?, QuotaDataSourceError>) -> Void)?

    public init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/sessions"), parser: RateLimitLogParser = .init()) {
        self.root = root
        self.parser = parser
    }

    public func start(onUpdate: @escaping @Sendable (Result<QuotaSnapshot?, QuotaDataSourceError>) -> Void) {
        callback = onUpdate
        refreshNow()
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        let descriptor = open(root.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: queue)
        source.setEventHandler { [weak self] in self?.scheduleRefresh() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        watcher = source
    }

    public func refreshNow() {
        queue.async { [weak self] in
            guard let self else { return }
            let result: Result<QuotaSnapshot?, QuotaDataSourceError>
            do { result = .success(try self.readLatestSnapshot()) }
            catch { result = .failure(.unreadable) }
            DispatchQueue.main.async { self.callback?(result) }
        }
    }

    public func stop() {
        debounce?.cancel(); debounce = nil
        watcher?.cancel(); watcher = nil
        callback = nil
    }

    public func readLatestSnapshot() throws -> QuotaSnapshot? {
        guard FileManager.default.fileExists(atPath: root.path) else { return nil }
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return nil }
        let files = enumerator.compactMap { $0 as? URL }
        let jsonlFiles = files.filter { $0.pathExtension == "jsonl" }.sorted {
            modificationDate(of: $0) > modificationDate(of: $1)
        }
        for file in jsonlFiles {
            if let snapshot = try parser.latestSnapshot(in: String(contentsOf: file), now: Date()) { return snapshot }
        }
        return nil
    }

    private func scheduleRefresh() {
        debounce?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.refreshNow() }
        debounce = item
        queue.asyncAfter(deadline: .now() + 2, execute: item)
    }

    private func modificationDate(of file: URL) -> Date {
        (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
