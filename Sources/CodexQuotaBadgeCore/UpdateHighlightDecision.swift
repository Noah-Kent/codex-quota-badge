import Foundation

public enum UpdateHighlightDecision {
    public static func shouldHighlight(previous: Date?, current: Date) -> Bool {
        guard let previous else { return false }
        return previous != current
    }
}
