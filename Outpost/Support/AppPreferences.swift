import Foundation

@MainActor
final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    enum Keys {
        static let startDaemonAtLaunch = "startDaemonAtLaunch"
        static let showTransfers = "showTransfers"
        static let browserViewMode = "browserViewMode"
        static let confirmDeletes = "confirmDeletes"
        static let clearCompletedTransfersAutomatically = "clearCompletedTransfersAutomatically"
        static let automaticallyCheckForUpdates = "automaticallyCheckForUpdates"
    }

    @Published var startDaemonAtLaunch: Bool {
        didSet { defaults.set(startDaemonAtLaunch, forKey: Keys.startDaemonAtLaunch) }
    }

    @Published var showTransfers: Bool {
        didSet { defaults.set(showTransfers, forKey: Keys.showTransfers) }
    }

    @Published var browserViewMode: BrowserViewMode {
        didSet { defaults.set(browserViewMode.rawValue, forKey: Keys.browserViewMode) }
    }

    @Published var confirmDeletes: Bool {
        didSet { defaults.set(confirmDeletes, forKey: Keys.confirmDeletes) }
    }

    @Published var clearCompletedTransfersAutomatically: Bool {
        didSet {
            defaults.set(clearCompletedTransfersAutomatically, forKey: Keys.clearCompletedTransfersAutomatically)
        }
    }

    @Published var automaticallyCheckForUpdates: Bool {
        didSet { defaults.set(automaticallyCheckForUpdates, forKey: Keys.automaticallyCheckForUpdates) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        startDaemonAtLaunch = defaults.object(forKey: Keys.startDaemonAtLaunch) as? Bool ?? true
        showTransfers = defaults.object(forKey: Keys.showTransfers) as? Bool ?? true
        let storedMode = defaults.string(forKey: Keys.browserViewMode)
        browserViewMode = storedMode.flatMap(BrowserViewMode.init(rawValue:)) ?? .list
        confirmDeletes = defaults.object(forKey: Keys.confirmDeletes) as? Bool ?? true
        clearCompletedTransfersAutomatically =
            defaults.object(forKey: Keys.clearCompletedTransfersAutomatically) as? Bool ?? false
        automaticallyCheckForUpdates = defaults.object(forKey: Keys.automaticallyCheckForUpdates) as? Bool ?? true
    }
}
