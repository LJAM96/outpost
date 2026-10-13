import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    @Published var remotes: [RcloneRemote] = []
    @Published var selectedRemote: RcloneRemote? = nil
    @Published var currentPath = ""
    @Published var items: [RemoteItem] = []
    @Published var isListing = false
    @Published var errorMessage: String?
    @Published var daemonRunning = false
    @Published var daemonVersion = ""
    @Published var transferJobs: [TransferJob] = []
    @Published var overallProgress: (bytes: Int64, total: Int64, speed: Double) = (0, 0, 0)
    @Published var selectedItems = Set<RemoteItem.ID>()
    @Published var mountedRemotes: Set<String> = []
    @Published var autoMountRemotes: Set<String> = []
    @Published var currentConfigPath: String?

    private var progressTimer: Timer?
    private var mountProcesses: [String: Process] = [:]
    private let service = RcloneService.shared
    private let daemonController = RcloneDaemonController.shared
    private let preferences = AppPreferences.shared

    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: "autoMountRemotes") {
            autoMountRemotes = Set(saved)
        }
        if let configURL = SecurityScopedBookmarkStore.shared.resolvedURL(for: SecurityScopedBookmarkStore.Key.rcloneConfig) {
            currentConfigPath = configURL.path
            UserDefaults.standard.set(configURL.path, forKey: "currentConfigPath")
        } else {
            currentConfigPath = UserDefaults.standard.string(forKey: "currentConfigPath")
        }
    }

    func checkDaemon() async {
        let running = await service.isRunning
        daemonRunning = running
        if !running {
            daemonVersion = ""
            if let daemonError = daemonController.lastError {
                errorMessage = daemonError
            }
            return
        }
        if running {
            do {
                daemonVersion = try await service.getVersion()
                try await loadRemotes()
                mountAutoRemotes()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func refresh() async {
        await checkDaemon()
        if selectedRemote != nil {
            await loadCurrentPath()
        }
    }

    func startDaemon() async {
        do {
            try await daemonController.start(configPath: currentConfigPath)
            await checkDaemon()
        } catch {
            errorMessage = "Failed to start daemon: \(error.localizedDescription)"
        }
    }

    func restartDaemon() async {
        do {
            try await daemonController.restart(configPath: currentConfigPath)
            await checkDaemon()
        } catch {
            errorMessage = "Failed to restart daemon: \(error.localizedDescription)"
        }
    }

    func stopDaemon() {
        daemonController.stop()
        daemonRunning = false
        daemonVersion = ""
    }

    func loadRemotes() async throws {
        remotes = try await service.listRemotes()
        if remotes.isEmpty {
            errorMessage = "No remotes configured. Add one with the + button."
        } else {
            errorMessage = nil
        }
    }

    func deleteRemote(_ remote: RcloneRemote) async {
        do {
            if mountedRemotes.contains(remote.name) {
                unmountRemote(remote)
            }
            try await service.deleteRemote(name: remote.name)
            if selectedRemote?.id == remote.id {
                selectedRemote = nil
                items = []
            }
            try await loadRemotes()
        } catch {
            errorMessage = "Failed to delete remote: \(error.localizedDescription)"
        }
    }

    func selectRemote(_ remote: RcloneRemote?) {
        selectedRemote = remote
        currentPath = ""
        selectedItems.removeAll()
        if remote != nil {
            Task { await loadCurrentPath() }
        } else {
            items = []
        }
    }

    func loadCurrentPath() async {
        guard let remote = selectedRemote else { return }
        isListing = true
        errorMessage = nil
        defer { isListing = false }
        do {
            items = try await service.listFiles(remote: remote.name, path: currentPath)
        } catch {
            errorMessage = "Failed to list files: \(error.localizedDescription)"
            items = []
        }
    }

    func navigateInto(_ item: RemoteItem) {
        guard item.isDirectory else { return }
        currentPath = currentPath.isEmpty ? item.path : "\(currentPath)/\(item.name)"
        Task { await loadCurrentPath() }
    }

    func navigateUp() {
        guard !currentPath.isEmpty else { return }
        let components = currentPath.split(separator: "/")
        currentPath = components.count <= 1 ? "" : components.dropLast().joined(separator: "/")
        Task { await loadCurrentPath() }
    }

    func navigateToPath(_ path: String) {
        currentPath = path
        Task { await loadCurrentPath() }
    }

    func createDirectory(name: String) async {
        guard let remote = selectedRemote, !name.isEmpty else { return }
        do {
            try await service.createDirectory(remote: remote.name, path: currentPath, directoryName: name)
            await loadCurrentPath()
        } catch {
            errorMessage = "Failed to create directory: \(error.localizedDescription)"
        }
    }

    func deleteItems(_ itemsToDelete: [RemoteItem], inPath path: String? = nil) async {
        guard let remote = selectedRemote else { return }
        let basePath = path ?? currentPath
        for item in itemsToDelete {
            do {
                if item.isDirectory {
                    try await service.deleteDirectory(remote: remote.name, path: basePath, directoryName: item.name)
                } else {
                    try await service.deleteItem(remote: remote.name, path: basePath, itemName: item.name)
                }
            } catch {
                errorMessage = "Failed to delete '\(item.name)': \(error.localizedDescription)"
                return
            }
        }
        await loadCurrentPath()
    }

    func downloadItems(_ itemsToDownload: [RemoteItem]) {
        guard let remote = selectedRemote else { return }
        for item in itemsToDownload {
            let job = TransferJob(remote: remote.name, remotePath: remotePath(for: item, in: currentPath),
                localPath: "", fileName: item.name, fileSize: item.size,
                direction: .download, status: .pending, bytesTransferred: 0)
            transferJobs.insert(job, at: 0)
            Task { await startDownload(job: job) }
        }
    }

    func downloadToLocal(_ itemsToDownload: [RemoteItem], fromPath path: String? = nil) {
        guard let remote = selectedRemote else { return }
        guard !itemsToDownload.isEmpty else { return }
        let basePath = path ?? currentPath
        let hasFolders = itemsToDownload.contains { $0.isDirectory }
        if hasFolders { downloadFoldersToLocal(itemsToDownload, fromPath: basePath); return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose download destination"
        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        for item in itemsToDownload {
            let localPath = destinationURL.appendingPathComponent(item.name).path
            let job = TransferJob(remote: remote.name, remotePath: remotePath(for: item, in: basePath),
                localPath: localPath, fileName: item.name, fileSize: item.size,
                direction: .download, status: .pending, bytesTransferred: 0)
            transferJobs.insert(job, at: 0)
            let didStartAccess = destinationURL.startAccessingSecurityScopedResource()
            Task {
                defer {
                    if didStartAccess {
                        destinationURL.stopAccessingSecurityScopedResource()
                    }
                }
                await startDownload(job: job)
            }
        }
    }

    private func downloadFoldersToLocal(_ items: [RemoteItem], fromPath basePath: String) {
        guard let remote = selectedRemote else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose download destination"
        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        for item in items {
            let remotePath = remotePath(for: item, in: basePath)
            let localPath = destinationURL.appendingPathComponent(item.name).path
            let job = TransferJob(remote: remote.name, remotePath: remotePath,
                localPath: localPath, fileName: item.name, fileSize: item.size,
                direction: .download, status: .transferring, bytesTransferred: 0)
            transferJobs.insert(job, at: 0)
            startProgressPolling()
            let didStartAccess = destinationURL.startAccessingSecurityScopedResource()
            Task {
                defer {
                    if didStartAccess {
                        destinationURL.stopAccessingSecurityScopedResource()
                    }
                }
                do {
                    let jobID = try await service.syncCopy(srcRemote: remote.name, srcPath: remotePath, dstPath: localPath)
                    updateTransferJob(job.id) { $0.rcloneJobID = jobID }
                    if isTransferCancelled(job.id) {
                        try? await service.stopJob(jobID: jobID)
                        return
                    }
                    var finished = false
                    while !finished {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        if isTransferCancelled(job.id) {
                            try? await service.stopJob(jobID: jobID)
                            return
                        }
                        let status = try await service.getJobStatus(jobID: jobID)
                        if let error = status.error {
                            updateTransferJob(job.id) {
                                $0.errorMessage = error
                                $0.status = .failed
                            }
                            return
                        }
                        updateTransferJob(job.id) { $0.bytesTransferred = status.bytes }
                        finished = status.finished
                    }
                    updateTransferJob(job.id) { $0.status = .completed }
                    clearCompletedTransferIfNeeded()
                } catch {
                    updateTransferJob(job.id) {
                        $0.errorMessage = error.localizedDescription
                        $0.status = .failed
                    }
                }
            }
        }
    }

    func uploadFiles(_ urls: [URL]) {
        guard let remote = selectedRemote else { return }
        for url in urls {
            let fileName = url.lastPathComponent
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            let dstPath = currentPath.isEmpty ? fileName : "\(currentPath)/\(fileName)"
            let job = TransferJob(remote: remote.name, remotePath: dstPath,
                localPath: url.path, fileName: fileName, fileSize: fileSize,
                direction: .upload, status: .pending, bytesTransferred: 0)
            transferJobs.insert(job, at: 0)
            let didStartAccess = url.startAccessingSecurityScopedResource()
            Task {
                defer {
                    if didStartAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                await startUpload(job: job)
            }
        }
    }

    func quickOpenFile(_ item: RemoteItem, inPath path: String? = nil) {
        guard let remote = selectedRemote, !item.isDirectory else { return }
        let basePath = path ?? currentPath
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Outpost")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let localURL = tempDir.appendingPathComponent(item.name)
        let job = TransferJob(remote: remote.name, remotePath: remotePath(for: item, in: basePath),
            localPath: localURL.path, fileName: item.name, fileSize: item.size,
            direction: .download, status: .transferring, bytesTransferred: 0)
        transferJobs.insert(job, at: 0)
        Task {
            await startDownload(job: job)
            if let index = transferJobs.firstIndex(where: { $0.id == job.id }),
               transferJobs[index].status == .completed {
                NSWorkspace.shared.open(localURL)
            }
        }
    }

    func mountRemote(_ remote: RcloneRemote) {
        guard let rclonePath = RcloneLauncher.findRclonePath() else {
            errorMessage = "rclone not found"
            return
        }

        let mountDir = "/tmp/outpost-mounts/\(remote.name)"
        try? FileManager.default.createDirectory(atPath: mountDir, withIntermediateDirectories: true)

        if mountProcesses[remote.name]?.isRunning == true {
            errorMessage = "\(remote.name) is already mounted"
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: rclonePath)
        process.arguments = ["mount", "\(remote.name):", mountDir, "--daemon"]
        if let configPath = currentConfigPath {
            process.arguments?.append(contentsOf: ["--config", configPath])
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            mountProcesses[remote.name] = process
            mountedRemotes.insert(remote.name)
            NSWorkspace.shared.open(URL(fileURLWithPath: mountDir))
        } catch {
            errorMessage = "Failed to mount: \(error.localizedDescription)"
        }
    }

    func unmountRemote(_ remote: RcloneRemote) {
        let mountDir = "/tmp/outpost-mounts/\(remote.name)"

        if let process = mountProcesses[remote.name], process.isRunning {
            process.terminate()
        }

        let umount = Process()
        umount.executableURL = URL(fileURLWithPath: "/sbin/umount")
        umount.arguments = [mountDir]
        umount.standardOutput = FileHandle.nullDevice
        umount.standardError = FileHandle.nullDevice
        do { try umount.run(); umount.waitUntilExit() } catch {}

        mountProcesses.removeValue(forKey: remote.name)
        mountedRemotes.remove(remote.name)
        try? FileManager.default.removeItem(atPath: mountDir)
    }

    func toggleAutoMount(_ remote: RcloneRemote) {
        if autoMountRemotes.contains(remote.name) {
            autoMountRemotes.remove(remote.name)
        } else {
            autoMountRemotes.insert(remote.name)
        }
        UserDefaults.standard.set(Array(autoMountRemotes), forKey: "autoMountRemotes")
    }

    private func mountAutoRemotes() {
        for remote in remotes where autoMountRemotes.contains(remote.name) {
            if !mountedRemotes.contains(remote.name) {
                mountRemote(remote)
            }
        }
    }

    func switchConfigPath(_ path: String?) {
        currentConfigPath = path
        if let path {
            UserDefaults.standard.set(path, forKey: "currentConfigPath")
        } else {
            UserDefaults.standard.removeObject(forKey: "currentConfigPath")
            SecurityScopedBookmarkStore.shared.removeBookmark(for: SecurityScopedBookmarkStore.Key.rcloneConfig)
        }
        Task {
            do {
                try await daemonController.restart(configPath: path)
                await checkDaemon()
            } catch {
                errorMessage = "Config changed, but rclone restart failed: \(error.localizedDescription)"
            }
        }
    }

    func chooseConfigFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "conf") ?? .data,
                                      UTType(filenameExtension: "rclone") ?? .data]
        panel.message = "Select rclone config file"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        SecurityScopedBookmarkStore.shared.saveBookmark(for: url, key: SecurityScopedBookmarkStore.Key.rcloneConfig)
        switchConfigPath(url.path)
    }

    private func startDownload(job: TransferJob) async {
        updateTransferJob(job.id) { $0.status = .transferring }
        startProgressPolling()
        let srcComponents = job.remotePath.split(separator: "/", omittingEmptySubsequences: true)
        let srcFile = srcComponents.last.map(String.init) ?? job.fileName
        let srcPath = srcComponents.dropLast().joined(separator: "/")
        let dstComponents = job.localPath.split(separator: "/", omittingEmptySubsequences: true)
        let dstFile = dstComponents.last.map(String.init) ?? job.fileName
        let dstPath = dstComponents.dropLast().joined(separator: "/")
        do {
            let jobID = try await service.copyFile(srcRemote: job.remote, srcPath: srcPath, srcFile: srcFile,
                dstRemote: "", dstPath: dstPath, dstFile: dstFile)
            updateTransferJob(job.id) { $0.rcloneJobID = jobID }
            if isTransferCancelled(job.id) {
                try? await service.stopJob(jobID: jobID)
                return
            }
            var finished = false
            while !finished {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                if isTransferCancelled(job.id) {
                    try? await service.stopJob(jobID: jobID)
                    return
                }
                let status = try await service.getJobStatus(jobID: jobID)
                if let error = status.error {
                    updateTransferJob(job.id) {
                        $0.errorMessage = error
                        $0.status = .failed
                    }
                    return
                }
                updateTransferJob(job.id) { $0.bytesTransferred = status.bytes }
                finished = status.finished
            }
            updateTransferJob(job.id) { $0.status = .completed }
            clearCompletedTransferIfNeeded()
        } catch {
            updateTransferJob(job.id) {
                $0.errorMessage = error.localizedDescription
                $0.status = .failed
            }
        }
    }

    private func startUpload(job: TransferJob) async {
        updateTransferJob(job.id) { $0.status = .transferring }
        startProgressPolling()
        let srcFile = (job.localPath as NSString).lastPathComponent
        let srcDir = (job.localPath as NSString).deletingLastPathComponent
        let dstComponents = job.remotePath.split(separator: "/", omittingEmptySubsequences: true)
        let dstFile = dstComponents.last.map(String.init) ?? job.fileName
        let dstPath = dstComponents.dropLast().joined(separator: "/")
        do {
            let jobID = try await service.copyFile(srcRemote: "", srcPath: srcDir, srcFile: srcFile,
                dstRemote: job.remote, dstPath: dstPath, dstFile: dstFile)
            updateTransferJob(job.id) { $0.rcloneJobID = jobID }
            if isTransferCancelled(job.id) {
                try? await service.stopJob(jobID: jobID)
                return
            }
            var finished = false
            while !finished {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                if isTransferCancelled(job.id) {
                    try? await service.stopJob(jobID: jobID)
                    return
                }
                let status = try await service.getJobStatus(jobID: jobID)
                if let error = status.error {
                    updateTransferJob(job.id) {
                        $0.errorMessage = error
                        $0.status = .failed
                    }
                    return
                }
                updateTransferJob(job.id) { $0.bytesTransferred = status.bytes }
                finished = status.finished
            }
            updateTransferJob(job.id) { $0.status = .completed }
            clearCompletedTransferIfNeeded()
        } catch {
            updateTransferJob(job.id) {
                $0.errorMessage = error.localizedDescription
                $0.status = .failed
            }
        }
    }

    private func updateTransferJob(_ id: TransferJob.ID, _ update: (inout TransferJob) -> Void) {
        guard let index = transferJobs.firstIndex(where: { $0.id == id }) else { return }
        update(&transferJobs[index])
    }

    private func isTransferCancelled(_ id: TransferJob.ID) -> Bool {
        transferJobs.first(where: { $0.id == id })?.status == .cancelled
    }

    private func remotePath(for item: RemoteItem, in basePath: String) -> String {
        RclonePath.childPath(basePath: basePath, itemName: item.name)
    }

    private func startProgressPolling() {
        guard progressTimer == nil else { return }
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let stats = try await self.service.getCoreStats()
                    self.overallProgress = (stats.bytes, stats.total, stats.speed)
                    if self.transferJobs.allSatisfy({ $0.status != .transferring }) {
                        self.stopProgressPolling()
                    }
                } catch {
                    self.stopProgressPolling()
                }
            }
        }
    }

    private func stopProgressPolling() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    func clearCompletedTransfers() {
        transferJobs.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
    }

    private func clearCompletedTransferIfNeeded() {
        guard preferences.clearCompletedTransfersAutomatically else { return }
        clearCompletedTransfers()
    }

    func cancelTransfer(_ job: TransferJob) {
        updateTransferJob(job.id) { transfer in
            transfer.status = .cancelled
            transfer.errorMessage = nil
        }
        if let jobID = job.rcloneJobID {
            Task { try? await service.stopJob(jobID: jobID) }
        }
    }

    func cancelAllTransfers() {
        let activeJobs = transferJobs.filter { $0.status == .pending || $0.status == .transferring }
        for job in activeJobs {
            cancelTransfer(job)
        }
    }

    func retryTransfer(_ job: TransferJob) {
        let retry = TransferJob(
            remote: job.remote,
            remotePath: job.remotePath,
            localPath: job.localPath,
            fileName: job.fileName,
            fileSize: job.fileSize,
            direction: job.direction,
            status: .pending,
            bytesTransferred: 0
        )
        transferJobs.insert(retry, at: 0)
        Task {
            switch retry.direction {
            case .download:
                await startDownload(job: retry)
            case .upload:
                await startUpload(job: retry)
            }
        }
    }

    func clearError() { errorMessage = nil }

    var currentPathDisplay: String {
        guard let remote = selectedRemote else { return "" }
        return currentPath.isEmpty ? "\(remote.name):" : "\(remote.name):/\(currentPath)"
    }
}

enum RcloneLauncher {
    static func findRclonePath() -> String? {
        let searchPaths = ["/opt/zerobrew/bin/rclone", "/opt/homebrew/bin/rclone", "/usr/local/bin/rclone"]
        for path in searchPaths {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        let whichTask = Process()
        whichTask.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichTask.arguments = ["rclone"]
        let pipe = Pipe()
        whichTask.standardOutput = pipe
        whichTask.standardError = FileHandle.nullDevice
        do {
            try whichTask.run()
            whichTask.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let found = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let found, !found.isEmpty, FileManager.default.isExecutableFile(atPath: found) { return found }
        } catch {}
        return nil
    }
}
