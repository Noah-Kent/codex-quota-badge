import Foundation

public enum RateLimitLogParserError: Error, Equatable {
    case invalidPayload
}

public struct RateLimitLogParser {
    public init() {}

    public func latestSnapshot(in jsonl: String, now: Date) throws -> QuotaSnapshot? {
        var latest: QuotaSnapshot?

        for line in jsonl.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = line.data(using: .utf8) else { continue }
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            if let snapshot = decodeSnapshot(from: object, now: now) {
                latest = snapshot
            }
        }

        return latest
    }

    private func decodeSnapshot(from object: [String: Any], now: Date) -> QuotaSnapshot? {
        let rateLimits = (object["rateLimits"] as? [String: Any])
            ?? ((object["params"] as? [String: Any])?["rateLimits"] as? [String: Any])

        guard let rateLimits else { return nil }

        var windows: [QuotaWindow] = []
        for key in ["primary", "secondary"] {
            if let window = decodeWindow(rateLimits[key] as? [String: Any], id: key) {
                windows.append(window)
            }
        }

        if windows.isEmpty,
           let byLimit = rateLimits["rateLimitsByLimitId"] as? [String: [String: Any]] {
            for (id, limit) in byLimit {
                for key in ["primary", "secondary"] {
                    if let window = decodeWindow(limit[key] as? [String: Any], id: "\(id)-\(key)") {
                        windows.append(window)
                    }
                }
            }
        }

        guard !windows.isEmpty else { return nil }
        return QuotaSnapshot(windows: windows.sorted { $0.duration < $1.duration }, updatedAt: now)
    }

    private func decodeWindow(_ dictionary: [String: Any]?, id: String) -> QuotaWindow? {
        guard let dictionary,
              let usedPercent = number(dictionary["usedPercent"]), (0...100).contains(usedPercent),
              let durationMinutes = number(dictionary["windowDurationMins"]), durationMinutes > 0,
              let resetTimestamp = number(dictionary["resetsAt"]), resetTimestamp > 0 else {
            return nil
        }

        return QuotaWindow(
            id: id,
            duration: durationMinutes * 60,
            usedPercent: usedPercent,
            resetsAt: Date(timeIntervalSince1970: resetTimestamp)
        )
    }

    private func number(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: number.doubleValue
        case let string as String: Double(string)
        default: nil
        }
    }
}
