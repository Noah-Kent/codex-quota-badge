import Foundation

public enum LogRefreshAction: Equatable, Sendable {
    case reuseCachedSnapshot
    case parseTrackedFile
    case rescanDirectory
}

public enum LogRefreshDecision {
    public static func choose(directoryChanged: Bool, trackedFileExists: Bool, cachedModificationDate: Date?, currentModificationDate: Date?) -> LogRefreshAction {
        guard !directoryChanged, trackedFileExists,
              let cachedModificationDate, let currentModificationDate else {
            return .rescanDirectory
        }
        return cachedModificationDate == currentModificationDate ? .reuseCachedSnapshot : .parseTrackedFile
    }
}
