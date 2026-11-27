import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: FloatingPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance guard: if another instance is already running, ask it to show and exit cleanly.
        if let myBundleId = Bundle.main.bundleIdentifier {
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: myBundleId)
                .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            if !others.isEmpty {
                DistributedNotificationCenter.default().postNotificationName(
                    FloatingPanelController.showNotificationName,
                    object: nil,
                    userInfo: nil,
                    deliverImmediately: true
                )
                NSApp.terminate(nil)
                return
            }
        }

        // Accessory app: lives cleanly in the Menu Bar + Floating Side HUD without cluttering the Dock.
        NSApp.setActivationPolicy(.accessory)
        self.controller = FloatingPanelController()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.handleExternalShowRequest()
        return true
    }
}

@main
struct GraviHUDApp {
    static func main() {
        if CommandLine.arguments.contains("--notify-ensure") {
            DistributedNotificationCenter.default().postNotificationName(
                FloatingPanelController.ensureNotificationName,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
