import AppKit
import CodexQuotaBadgeCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: QuotaStore?
    private var panel: QuotaBadgePanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isPreview = ProcessInfo.processInfo.environment["CODEX_QUOTA_PREVIEW"] == "1"
        let source: QuotaDataSource = isPreview ? PreviewQuotaDataSource() : LocalLogQuotaDataSource()
        let store = QuotaStore(source: source)
        self.store = store
        let panel = QuotaBadgePanel(store: store)
        self.panel = panel
        store.start()
        if isPreview {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                panel.showForPreview()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) { store?.stop() }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
