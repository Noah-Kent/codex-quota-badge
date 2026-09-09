import CoreServices
import Dispatch
import Foundation

public final class LocalLogQuotaDataSource: QuotaDataSource, @unchecked Sendable {
    private let root: URL
    private let parser: RateLimitLogParser
    private let queue = DispatchQueue(label: "CodexQuotaBadge.LocalLogQuotaDataSource")
    private var callback: (@Sendable (Result<QuotaSnapshot?, QuotaDataSourceError>) -> Void)?
    private var eventStream: FSEventStreamRef?
    private var watchedRoot: URL?
    private var directoryChanged = true
    private var trackedFile: URL?
    private var trackedModificationDate: Date?
    private var cachedSnapshot: QuotaSnapshot?

    public init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/sessions"), parser: RateLimitLogParser = .init()) {
        self.root = root
        self.parser = parser
    }

    public func start(onUpdate: @escaping @Sendable (Result<QuotaSnapshot?, QuotaDataSourceError>) -> Void) {
        callback = onUpdate
        queue.async { [weak self] in
            self?.startWatching()
            self?.performRefresh()
        }
    }

    public func refreshNow() {
        queue.async { [weak self] in self?.performRefresh() }
    }

    public func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopWatching()
            self.callback = nil
        }
    }

    public func readLatestSnapshot() throws -> QuotaSnapshot? {
        let currentDate = trackedFile.flatMap(modificationDate(of:))
        let action = LogRefreshDecision.choose(
            directoryChanged: directoryChanged,
            trackedFileExists: trackedFile != nil && currentDate != nil,
            cachedModificationDate: trackedModificationDate,
            currentModificationDate: currentDate
        )
        switch action {
        case .reuseCachedSnapshot:
            return cachedSnapshot
        case .parseTrackedFile:
            if let trackedFile, let snapshot = try parse(file: trackedFile) {
                cachedSnapshot = snapshot
                trackedModificationDate = modificationDate(of: trackedFile)
                directoryChanged = false
                return snapshot
            }
            directoryChanged = true
            return try rescanDirectory()
        case .rescanDirectory:
            return try rescanDirectory()
        }
    }

    private func performRefresh() {
        startWatching()
        let result: Result<QuotaSnapshot?, QuotaDataSourceError>
        do { result = .success(try readLatestSnapshot()) }
        catch { result = .failure(.unreadable) }
        DispatchQueue.main.async { [weak self] in self?.callback?(result) }
    }

    private func rescanDirectory() throws -> QuotaSnapshot? {
        guard FileManager.default.fileExists(atPath: root.path) else {
            clearCache(); return nil
        }
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return nil }
        let files = enumerator.compactMap { $0 as? URL }
        let jsonlFiles = files.filter { $0.pathExtension == "jsonl" }.sorted {
            (modificationDate(of: $0) ?? .distantPast) > (modificationDate(of: $1) ?? .distantPast)
        }
        for file in jsonlFiles {
            if let snapshot = try parse(file: file) {
                trackedFile = file
                trackedModificationDate = modificationDate(of: file)
                cachedSnapshot = snapshot
                directoryChanged = false
                return snapshot
            }
        }
        clearCache()
        return nil
    }

    private func parse(file: URL) throws -> QuotaSnapshot? {
        try parser.latestSnapshot(inTailOf: file, now: Date())
    }

    private func clearCache() {
        trackedFile = nil
        trackedModificationDate = nil
        cachedSnapshot = nil
        directoryChanged = false
    }

    private func modificationDate(of file: URL) -> Date? {
        try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func startWatching() {
        let watchRoot = LogWatchPath.url(
            for: root,
            sessionDirectoryExists: FileManager.default.fileExists(atPath: root.path)
        )
        guard eventStream == nil || watchedRoot != watchRoot else { return }
        stopWatching()
        guard FileManager.default.fileExists(atPath: watchRoot.path) else { return }
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            Self.eventCallback,
            &context,
            [watchRoot.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else { return }
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        eventStream = stream
        watchedRoot = watchRoot
    }

    private func stopWatching() {
        if let eventStream {
            FSEventStreamStop(eventStream)
            FSEventStreamInvalidate(eventStream)
            FSEventStreamRelease(eventStream)
            self.eventStream = nil
        }
        watchedRoot = nil
    }

    private static let eventCallback: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
        guard let info else { return }
        let source = Unmanaged<LocalLogQuotaDataSource>.fromOpaque(info).takeUnretainedValue()
        let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
        source.handleFileEvents(paths)
    }

    private func handleFileEvents(_ paths: [String]) {
        guard let trackedPath = trackedFile?.path else {
            directoryChanged = true
            return
        }
        if paths.contains(where: { $0 != trackedPath }) { directoryChanged = true }
    }
}
