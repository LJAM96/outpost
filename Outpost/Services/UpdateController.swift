import AppKit
import Foundation

@MainActor
final class UpdateController: ObservableObject {
    static let shared = UpdateController()

    @Published private(set) var lastCheckSummary: String?

    private let releasesURL = URL(string: "https://github.com/LJAM96/outpost/releases")!

    func checkForUpdates() {
        lastCheckSummary = "Opening GitHub releases"
        NSWorkspace.shared.open(releasesURL)
    }
}
