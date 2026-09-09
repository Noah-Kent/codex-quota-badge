import Foundation

public enum RateLimitLogParserError: Error, Equatable {
    case invalidPayload
}

public struct RateLimitLogParser {
    public init() {}

    public func latestSnapshot(in jsonl: String, now: Date) throws -> QuotaSnapshot? {
        var latest: QuotaSnapshot?

        for line in jsonl.split(separator: "\n", omittingEmptySubsequences: true) {
            if let snapshot = snapshot(in: line, now: now) {
                latest = snapshot
            }
        }

        return latest
    }

    public func latestSnapshot(inTailOf file: URL, now: Date, chunkSize: Int = 64 * 1024) throws -> QuotaSnapshot? {
        precondition(chunkSize > 0)

        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }

        var offset = try handle.seekToEnd()
        var leadingFragment = Data()

        while offset > 0 {
            let byteCount = Int(min(UInt64(chunkSize), offset))
            offset -= UInt64(byteCount)
            try handle.seek(toOffset: offset)
            guard let chunk = try handle.read(upToCount: byteCount) else { continue }

            var bytes = Data()
            bytes.append(chunk)
            bytes.append(leadingFragment)
            let lines = bytes.split(separator: 0x0A, omittingEmptySubsequences: false)

            let completeLines: ArraySlice<Data.SubSequence>
            if offset > 0 {
                leadingFragment = Data(lines.first ?? Data())
                completeLines = lines.dropFirst()
            } else {
                completeLines = lines[...]
            }

            for line in completeLines.reversed() {
                if let snapshot = snapshot(in: String(decoding: line, as: UTF8.self), now: now) {
                    return snapshot
                }
            }
        }

        return nil
    }

    private func snapshot<S: StringProtocol>(in line: S, now: Date) -> QuotaSnapshot? {
        guard let data = String(line).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return decodeSnapshot(from: object, now: now)
    }

    private func decodeSnapshot(from object: [String: Any], now: Date) -> QuotaSnapshot? {
        let rateLimits = (object["rateLimits"] as? [String: Any])
            ?? ((object["params"] as? [String: Any])?["rateLimits"] as? [String: Any])
            ?? ((object["payload"] as? [String: Any])?["rate_limits"] as? [String: Any])

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
              let usedPercent = number(dictionary["usedPercent"] ?? dictionary["used_percent"]), (0...100).contains(usedPercent),
              let durationMinutes = number(dictionary["windowDurationMins"] ?? dictionary["window_minutes"]), durationMinutes > 0,
              let resetTimestamp = number(dictionary["resetsAt"] ?? dictionary["resets_at"]), resetTimestamp > 0 else {
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
