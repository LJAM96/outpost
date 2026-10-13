import XCTest
@testable import Outpost

final class RclonePathTests: XCTestCase {
    func testRemoteFsKeepsRemotePrefix() {
        XCTAssertEqual(RclonePath.fs(remote: "drive", path: "folder"), "drive:folder")
        XCTAssertEqual(RclonePath.fs(remote: "drive", path: ""), "drive:")
    }

    func testLocalFsAddsLeadingSlashOnlyWhenNeeded() {
        XCTAssertEqual(RclonePath.fs(remote: "", path: "Users/luke/file.txt"), "/Users/luke/file.txt")
        XCTAssertEqual(RclonePath.fs(remote: "", path: "/Users/luke/file.txt"), "/Users/luke/file.txt")
    }

    func testChildPathJoinsWithoutLeadingSeparatorAtRoot() {
        XCTAssertEqual(RclonePath.childPath(basePath: "", itemName: "file.txt"), "file.txt")
        XCTAssertEqual(RclonePath.childPath(basePath: "folder", itemName: "file.txt"), "folder/file.txt")
    }
}

