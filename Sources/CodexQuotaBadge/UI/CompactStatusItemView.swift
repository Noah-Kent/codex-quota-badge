import AppKit
import CodexQuotaBadgeCore

final class CompactStatusItemView: NSView {
    var onClick: (() -> Void)?
    private var rows: [String] = []

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 48, height: NSStatusBar.system.thickness))
        toolTip = "Codex 配额"
    }

    required init?(coder: NSCoder) { nil }

    func update(snapshot: QuotaSnapshot?) {
        rows = MenuBarSummaryFormatter.compactRows(for: snapshot)
        isHidden = rows.isEmpty
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        for (index, row) in rows.enumerated() {
            let rect = NSRect(x: 0, y: index == 0 ? 10 : 1, width: bounds.width, height: 10)
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: style]
            row.draw(in: rect, withAttributes: attributes)
        }
    }

    override func mouseDown(with event: NSEvent) { onClick?() }
}
