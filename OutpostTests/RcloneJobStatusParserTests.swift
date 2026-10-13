import XCTest
@testable import Outpost

final class RcloneJobStatusParserTests: XCTestCase {
    func testParsesFinishedJobStatus() throws {
        let data = Data("""
        {
          "finished": true,
          "error": "",
          "output": {
            "bytes": 42,
            "total": 100
          }
        }
        """.utf8)

        let status = try RcloneJobStatusParser.parse(data)

        XCTAssertEqual(status, RcloneJobStatus(bytes: 42, total: 100, finished: true, error: nil))
    }

    func testPreservesNonEmptyError() throws {
        let data = Data("""
        {
          "finished": true,
          "error": "remote failed"
        }
        """.utf8)

        let status = try RcloneJobStatusParser.parse(data)

        XCTAssertEqual(status.error, "remote failed")
    }

    func testParsesFoundationNumberValues() throws {
        let object: [String: Any] = [
            "finished": false,
            "output": [
                "bytes": NSNumber(value: 9_223),
                "total": NSNumber(value: 10_000)
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: object)

        let status = try RcloneJobStatusParser.parse(data)

        XCTAssertEqual(status.bytes, 9_223)
        XCTAssertEqual(status.total, 10_000)
        XCTAssertFalse(status.finished)
    }
}
