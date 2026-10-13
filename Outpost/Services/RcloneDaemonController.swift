import Combine
import Foundation

@MainActor
final class RcloneDaemonController: ObservableObject {
    static let shared = RcloneDaemonController()

    @Published private(set) var processRunning = false
    @Published private(set) var managedProcessID: Int32?
    @Published var lastError: String?

    private var process: Process?
    private let service: RcloneService
    private let rcAddress = "127.0.0.1:5572"
    private var scopedConfigURL: URL?
    private var scopedConfigAccessStarted = false

    init(service: RcloneService = .shared) {
        self.service = service
    }

    func start(configPath: String?) async throws {
        if await service.isRunning {
            processRunning = true
            lastError = nil
            return
        }

        guard process?.isRunning != true else {
            processRunning = true
            return
        }

        guard let rclonePath = RcloneLauncher.findRclonePath() else {
            lastError = "rclone not found"
            throw RcloneError.daemonNotRunning
        }

        let newProcess = Process()
        newProcess.executableURL = URL(fileURLWithPath: rclonePath)
        var args = ["rcd", "--rc-addr=\(rcAddress)", "--rc-no-auth"]
        if let configPath {
            let configURL = SecurityScopedBookmarkStore.shared.resolvedURL(for: SecurityScopedBookmarkStore.Key.rcloneConfig)
                ?? URL(fileURLWithPath: configPath)
            scopedConfigAccessStarted = configURL.startAccessingSecurityScopedResource()
            scopedConfigURL = configURL
            args.append(contentsOf: ["--config", configURL.path])
        }
        newProcess.arguments = args
        newProcess.standardOutput = FileHandle.nullDevice
        newProcess.standardError = FileHandle.nullDevice
        newProcess.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.processRunning = false
                self.managedProcessID = nil
                self.process = nil
            }
        }

        do {
            try newProcess.run()
            process = newProcess
            processRunning = true
            managedProcessID = newProcess.processIdentifier
            lastError = nil

            try await Task.sleep(nanoseconds: 1_500_000_000)
            guard await service.isRunning else {
                stop()
                lastError = "Rclone daemon failed to start"
                throw RcloneError.daemonNotRunning
            }
        } catch {
            stop()
            lastError = "Failed to start daemon: \(error.localizedDescription)"
            throw error
        }
    }

    func restart(configPath: String?) async throws {
        stop()
        try await start(configPath: configPath)
    }

    func stop() {
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        managedProcessID = nil
        processRunning = false
        if scopedConfigAccessStarted {
            scopedConfigURL?.stopAccessingSecurityScopedResource()
        }
        scopedConfigURL = nil
        scopedConfigAccessStarted = false
    }
}
