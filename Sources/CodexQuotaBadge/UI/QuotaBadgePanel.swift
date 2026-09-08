import AppKit
import SwiftUI
import CodexQuotaBadgeCore

@MainActor
final class QuotaBadgePanel: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel: NSPanel

    init(store: QuotaStore) {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 270, height: 100), styleMask: [.nonactivatingPanel, .titled], backing: .buffered, defer: false)
        super.init()
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.contentView = NSHostingView(rootView: QuotaBadgeView(store: store))
        statusItem.button?.title = "⌁ 配额"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle)
    }

    @objc private func toggle() {
        if panel.isVisible { panel.orderOut(nil); return }
        guard let button = statusItem.button, let window = button.window else { return }
        let point = window.convertToScreen(button.convert(button.bounds, to: nil)).origin
        panel.setFrameTopLeftPoint(NSPoint(x: point.x - 210, y: point.y))
        panel.orderFrontRegardless()
    }
}
