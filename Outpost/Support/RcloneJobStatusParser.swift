import Foundation

struct RcloneJobStatus: Equatable {
    let bytes: Int64
    let total: Int64
    let finished: Bool
    let error: String?
}

enum RcloneJobStatusParser {
    static func parse(_ data: Data) throws -> RcloneJobStatus {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RcloneError.invalidResponse
        }

        let finished = dict["finished"] as? Bool ?? false
        let errorString = dict["error"] as? String
        let error = errorString?.isEmpty == false ? errorString : nil
        let output = dict["output"] as? [String: Any]
        let bytes = int64Value(output?["bytes"])
        let total = int64Value(output?["total"])

        return RcloneJobStatus(bytes: bytes, total: total, finished: finished, error: error)
    }

    private static func int64Value(_ value: Any?) -> Int64 {
        switch value {
        case let value as Int64:
            return value
        case let value as Int:
            return Int64(value)
        case let value as Double:
            return Int64(value)
        case let value as NSNumber:
            return value.int64Value
        default:
            return 0
        }
    }
}
