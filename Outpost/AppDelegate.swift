import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let daemonController = RcloneDaemonController.shared
    private let preferences = AppPreferences.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        guard preferences.startDaemonAtLaunch else { return }
        Task { @MainActor in
            do {
                let configPath = UserDefaults.standard.string(forKey: "currentConfigPath")
                try await daemonController.start(configPath: configPath)
                NotificationCenter.default.post(name: .rcloneDaemonStatusChanged, object: nil)
            } catch {
                NotificationCenter.default.post(name: .rcloneDaemonStatusChanged, object: nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        daemonController.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

extension Notification.Name {
    static let rcloneDaemonStatusChanged = Notification.Name("rcloneDaemonStatusChanged")
}
