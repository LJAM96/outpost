import XCTest
@testable import Outpost

final class TransferJobTests: XCTestCase {
    func testProgressUsesTransferredBytesAndFileSize() {
        let job = TransferJob(
            remote: "drive",
            remotePath: "folder/file.txt",
            localPath: "/tmp/file.txt",
            fileName: "file.txt",
            fileSize: 200,
            direction: .download,
            status: .transferring,
            bytesTransferred: 50
        )

        XCTAssertEqual(job.progress, 0.25)
        XCTAssertEqual(job.formattedProgress, "25%")
    }

    func testCancelledProgressTextIsExplicit() {
        let job = TransferJob(
            remote: "drive",
            remotePath: "folder/file.txt",
            localPath: "/tmp/file.txt",
            fileName: "file.txt",
            fileSize: 200,
            direction: .download,
            status: .cancelled,
            bytesTransferred: 50
        )

        XCTAssertEqual(job.formattedProgress, "Cancelled")
    }
}
