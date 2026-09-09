import AppKit
import Combine
import SwiftUI
import CodexQuotaBadgeCore

@MainActor
final class QuotaBadgePanel: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel: NSPanel
    private let compactView = CompactStatusItemView()
    private var availabilityObserver: AnyCancellable?

    init(store: QuotaStore) {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 104), styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        super.init()
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: QuotaBadgeView(
            store: store,
            onHide: { [weak self] in self?.panel.orderOut(nil) },
            onQuit: { NSApp.terminate(nil) }
        ))
        statusItem.button?.title = "未检测到配额"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle)
        compactView.onClick = { [weak self] in self?.toggle() }
        compactView.autoresizingMask = [.width, .height]
        availabilityObserver = store.$availability.sink { [weak self] availability in
            self?.apply(availability)
        }
    }

    @objc private func toggle() {
        if panel.isVisible { panel.orderOut(nil); return }
        guard let button = statusItem.button, let window = button.window else { return }
        let point = window.convertToScreen(button.convert(button.bounds, to: nil)).origin
        panel.setFrameTopLeftPoint(NSPoint(x: point.x - 260, y: point.y))
        panel.orderFrontRegardless()
    }

    func showForPreview() {
        panel.center()
        panel.orderFrontRegardless()
    }

    private func apply(_ availability: QuotaAvailability) {
        switch availability {
        case .fresh(let snapshot), .stale(let snapshot, _):
            statusItem.length = 48
            statusItem.button?.title = ""
            attachCompactView()
            compactView.update(snapshot: snapshot)
        case .unavailable:
            compactView.update(snapshot: nil)
            statusItem.length = NSStatusItem.variableLength
            statusItem.button?.title = MenuBarSummaryFormatter.text(for: nil)
        }
    }

    private func attachCompactView() {
        guard let button = statusItem.button else { return }
        compactView.frame = button.bounds
        if compactView.superview !== button { button.addSubview(compactView) }
    }
}
