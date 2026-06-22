import SwiftUI
import AppKit
import QuickLookThumbnailing

actor ThumbnailCache {
    static let shared = ThumbnailCache()
    private var cache: [String: NSImage] = [:]

    private init() {}

    func thumbnail(for item: RemoteItem, remote: String, path: String) async -> NSImage? {
        let cacheKey = "\(remote)/\(path)/\(item.name)"
        if let cached = cache[cacheKey] { return cached }

        guard !item.isDirectory else { return nil }

        let ext = (item.name as NSString).pathExtension.lowercased()
        let imageExts = ["jpg", "jpeg", "png", "gif", "heic", "webp", "bmp", "tiff", "heif"]
        let videoExts = ["mp4", "mov", "avi", "mkv", "m4v"]
        let docExts = ["pdf"]

        guard imageExts.contains(ext) || videoExts.contains(ext) || docExts.contains(ext) else { return nil }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("OutpostThumbs")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let localURL = tempDir.appendingPathComponent(item.name)

        if !FileManager.default.fileExists(atPath: localURL.path) {
            do {
                let jobID = try await RcloneService.shared.copyFile(
                    srcRemote: remote, srcPath: path, srcFile: item.name,
                    dstRemote: "", dstPath: tempDir.path, dstFile: item.name
                )
                var finished = false
                while !finished {
                    try await Task.sleep(nanoseconds: 500_000_000)
                    let status = try await RcloneService.shared.getJobStatus(jobID: jobID)
                    finished = status.finished
                }
            } catch {
                return nil
            }
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: localURL,
            size: CGSize(width: 128, height: 128),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, error in
                if let thumbnail {
                    continuation.resume(returning: thumbnail.nsImage)
                } else {
                    let icon = NSWorkspace.shared.icon(forFile: localURL.path)
                    let resized = NSImage(size: NSSize(width: 128, height: 128))
                    resized.lockFocus()
                    icon.draw(in: NSRect(x: 0, y: 0, width: 128, height: 128),
                              from: NSRect(origin: .zero, size: icon.size),
                              operation: .copy, fraction: 1.0)
                    resized.unlockFocus()
                    continuation.resume(returning: resized)
                }
            }
        }
    }
}

struct ThumbnailView: View {
    let item: RemoteItem
    let size: CGFloat

    @EnvironmentObject var viewModel: AppViewModel
    @State private var thumbnail: NSImage?

    private var remotePath: String {
        guard let remote = viewModel.selectedRemote else { return "" }
        return viewModel.currentPath
    }

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                FileIcon(fileName: item.name, isDirectory: item.isDirectory, size: size)
                    .task {
                        guard !item.isDirectory,
                              let remote = viewModel.selectedRemote else { return }
                        thumbnail = await ThumbnailCache.shared.thumbnail(
                            for: item,
                            remote: remote.name,
                            path: viewModel.currentPath
                        )
                    }
            }
        }
    }
}
