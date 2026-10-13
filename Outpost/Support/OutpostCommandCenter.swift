import Foundation

@MainActor
final class OutpostCommandCenter: ObservableObject {
    static let shared = OutpostCommandCenter()

    @Published private(set) var newFolderRequest = 0
    @Published private(set) var uploadRequest = 0
    @Published private(set) var downloadRequest = 0
    @Published private(set) var deleteRequest = 0
    @Published private(set) var refreshRequest = 0
    @Published private(set) var toggleTransfersRequest = 0

    func requestNewFolder() { newFolderRequest += 1 }
    func requestUpload() { uploadRequest += 1 }
    func requestDownload() { downloadRequest += 1 }
    func requestDelete() { deleteRequest += 1 }
    func requestRefresh() { refreshRequest += 1 }
    func requestToggleTransfers() { toggleTransfersRequest += 1 }
}
