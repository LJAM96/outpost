import Foundation

actor RcloneService {
    static let shared = RcloneService()

    private let baseURL = "http://localhost:5572"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    var isRunning: Bool {
        get async { await checkStatus() }
    }

    private func checkStatus() async -> Bool {
        do {
            let data = try await post(endpoint: "rc/noop", body: [:])
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return dict != nil
        } catch {
            return false
        }
    }

    func getVersion() async throws -> String {
        let data = try await post(endpoint: "core/version", body: [:])
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return dict?["version"] as? String ?? "unknown"
    }

    func listRemotes() async throws -> [RcloneRemote] {
        let data = try await post(endpoint: "config/dump", body: [:])
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        var remotes: [RcloneRemote] = []
        for (key, value) in dict {
            guard let section = value as? [String: Any],
                  let remoteType = section["type"] as? String else { continue }
            remotes.append(RcloneRemote(name: key, type: remoteType))
        }
        return remotes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func listFiles(remote: String, path: String) async throws -> [RemoteItem] {
        let fs = "\(remote):\(path)"
        let body: [String: Any] = ["fs": fs, "remote": ""]
        let data = try await post(endpoint: "operations/list", body: body)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = dict["list"] as? [[String: Any]] else {
            throw RcloneError.invalidResponse
        }
        let jsonData = try JSONSerialization.data(withJSONObject: list, options: [])
        return try JSONDecoder().decode([RemoteItem].self, from: jsonData)
    }

    func statFile(remote: String, path: String) async throws -> RemoteItem {
        let fs = "\(remote):\(path)"
        let body: [String: Any] = ["fs": fs]
        let data = try await post(endpoint: "operations/stat", body: body)
        return try JSONDecoder().decode(RemoteItem.self, from: data)
    }

    func createDirectory(remote: String, path: String, directoryName: String) async throws {
        let body: [String: Any] = ["fs": "\(remote):\(path)", "remote": directoryName]
        _ = try await post(endpoint: "operations/mkdir", body: body)
    }

    func deleteItem(remote: String, path: String, itemName: String) async throws {
        let body: [String: Any] = ["fs": "\(remote):\(path)", "remote": itemName]
        _ = try await post(endpoint: "operations/deletefile", body: body)
    }

    func copyFile(srcRemote: String, srcPath: String, srcFile: String,
                   dstRemote: String, dstPath: String, dstFile: String) async throws -> String {
        let body: [String: Any] = [
            "srcFs": "\(srcRemote):\(srcPath)",
            "dstFs": "\(dstRemote):\(dstPath)",
            "srcRemote": srcFile,
            "dstRemote": dstFile
        ]
        let data = try await post(endpoint: "operations/copyfile", body: body)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let jobID = dict?["jobid"] as? Int else { throw RcloneError.invalidResponse }
        return String(jobID)
    }

    func syncCopy(srcRemote: String, srcPath: String, dstPath: String) async throws -> String {
        let body: [String: Any] = ["srcFs": "\(srcRemote):\(srcPath)", "dstFs": dstPath]
        let data = try await post(endpoint: "sync/copy", body: body)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let jobID = dict?["jobid"] as? Int else { throw RcloneError.invalidResponse }
        return String(jobID)
    }

    func getJobStatus(jobID: String) async throws -> (bytes: Int64, total: Int64, finished: Bool, error: String?) {
        let body: [String: Any] = ["jobid": Int(jobID) ?? 0]
        let data = try await post(endpoint: "job/status", body: body)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RcloneError.invalidResponse
        }
        let finished = dict["finished"] as? Bool ?? false
        let error = dict["error"] as? String
        var bytes: Int64 = 0
        var total: Int64 = 0
        if let output = dict["output"] as? [String: Any] {
            bytes = output["bytes"] as? Int64 ?? 0
            total = output["total"] as? Int64 ?? 0
        }
        return (bytes, total, finished, error)
    }

    func listProviders() async throws -> [String] {
        let data = try await post(endpoint: "config/providers", body: [:])
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let providers = dict["providers"] as? [[String: Any]] else {
            throw RcloneError.invalidResponse
        }
        return providers.compactMap { $0["Name"] as? String }.sorted()
    }

    func getProviderOptions(_ provider: String) async throws -> [[String: Any]] {
        let body: [String: Any] = ["provider": provider]
        let data = try await post(endpoint: "config/options", body: body)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let options = dict["options"] as? [[String: Any]] else {
            return []
        }
        return options
    }

    func createRemote(name: String, type: String, parameters: [String: String]) async throws {
        let body: [String: Any] = ["name": name, "type": type, "parameters": parameters]
        _ = try await post(endpoint: "config/create", body: body)
    }

    func createRemoteInteractive(name: String, type: String, parameters: [String: String]) async throws -> RcloneConfigPrompt? {
        let body: [String: Any] = [
            "name": name, "type": type, "parameters": parameters,
            "opt": ["nonInteractive": true]
        ]
        let data = try await post(endpoint: "config/create", body: body)
        return try? JSONDecoder().decode(RcloneConfigPrompt.self, from: data)
    }

    func continueCreateRemote(name: String, state: String, result: String) async throws -> RcloneConfigPrompt? {
        let body: [String: Any] = [
            "name": name,
            "opt": ["continue": true, "state": state, "result": result, "nonInteractive": true]
        ]
        let data = try await post(endpoint: "config/create", body: body)
        return try? JSONDecoder().decode(RcloneConfigPrompt.self, from: data)
    }

    func updateRemote(name: String, parameters: [String: String]) async throws {
        let body: [String: Any] = ["name": name, "parameters": parameters]
        _ = try await post(endpoint: "config/update", body: body)
    }

    func getRemote(name: String) async throws -> (type: String, parameters: [String: String]) {
        let body: [String: Any] = ["name": name]
        let data = try await post(endpoint: "config/get", body: body)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RcloneError.invalidResponse
        }
        let type = dict["type"] as? String ?? ""
        let parameters = (dict["parameters"] as? [String: String]) ?? [:]
        return (type, parameters)
    }

    func deleteRemote(name: String) async throws {
        let body: [String: Any] = ["name": name]
        _ = try await post(endpoint: "config/delete", body: body)
    }

    func getCoreStats() async throws -> (bytes: Int64, total: Int64, speed: Double, transfers: Int) {
        let data = try await post(endpoint: "core/stats", body: [:])
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RcloneError.invalidResponse
        }
        let bytes = dict["bytes"] as? Int64 ?? 0
        let total = dict["totalBytes"] as? Int64 ?? 0
        let speed = dict["speed"] as? Double ?? 0
        let transfers = dict["transfers"] as? Int ?? 0
        return (bytes, total, speed, transfers)
    }

    private func post(endpoint: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw RcloneError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RcloneError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = errorDict["error"] as? String {
                throw RcloneError.serverError(errorMsg)
            }
            throw RcloneError.httpError(httpResponse.statusCode)
        }
        return data
    }
}

struct RcloneConfigPrompt: Codable {
    let state: String?
    let option: RcloneConfigOption?
    let oauth: RcloneOAuthInfo?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case state = "State"
        case option = "Option"
        case oauth = "OAuth"
        case error
    }
}

struct RcloneConfigOption: Codable {
    let name: String?
    let help: String?
    let isPassword: Bool?
    let required: Bool?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case help = "Help"
        case isPassword = "IsPassword"
        case required = "Required"
    }
}

struct RcloneOAuthInfo: Codable {
    let authURL: String?
    let tokenURL: String?

    enum CodingKeys: String, CodingKey {
        case authURL = "AuthURL"
        case tokenURL = "TokenURL"
    }
}

enum RcloneError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case daemonNotRunning

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from rclone daemon"
        case .httpError(let code): return "HTTP error \(code)"
        case .serverError(let msg): return msg
        case .daemonNotRunning: return "Rclone daemon is not running"
        }
    }
}
