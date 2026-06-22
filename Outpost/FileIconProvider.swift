import SwiftUI
import AppKit

final class FileIconProvider {
    static let shared = FileIconProvider()
    private var cache: [String: NSImage] = [:]

    private init() {}

    func icon(for fileName: String, isDirectory: Bool, size: CGFloat = 16) -> NSImage {
        let cacheKey = isDirectory ? "__folder__:\(size)" : "\(fileName):\(size)"

        if let cached = cache[cacheKey] { return cached }

        let icon: NSImage
        if isDirectory {
            icon = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
        } else {
            let ext = (fileName as NSString).pathExtension.lowercased()
            icon = ext.isEmpty
                ? NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericDocumentIcon)))
                : NSWorkspace.shared.icon(forFileType: ext)
        }

        let resized = NSImage(size: NSSize(width: size, height: size))
        resized.lockFocus()
        icon.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                  from: NSRect(origin: .zero, size: icon.size),
                  operation: .copy, fraction: 1.0)
        resized.unlockFocus()

        cache[cacheKey] = resized
        return resized
    }
}

struct FileIcon: View {
    let fileName: String
    let isDirectory: Bool
    var size: CGFloat = 16

    var body: some View {
        Image(nsImage: FileIconProvider.shared.icon(for: fileName, isDirectory: isDirectory, size: size))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
