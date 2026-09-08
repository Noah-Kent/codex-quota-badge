import AppKit
import CodexQuotaBadgeCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: QuotaStore?
    private var panel: QuotaBadgePanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = QuotaStore(source: LocalLogQuotaDataSource())
        self.store = store
        panel = QuotaBadgePanel(store: store)
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) { store?.stop() }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
