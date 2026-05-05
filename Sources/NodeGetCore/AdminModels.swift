import Foundation

public extension NodeGetClient {
    func serverVersion() async throws -> String {
        try await call(method: "nodeget-server_version", params: EmptyParams(), resultType: String.self)
    }

    func serverUUID() async throws -> String {
        try await call(method: "nodeget-server_uuid", params: EmptyParams(), resultType: String.self)
    }

    func listTokens(token: String) async throws -> [AdminToken] {
        let result: AdminTokenListResult = try await call(
            method: "token_list_all_tokens",
            params: TokenParams(token: token),
            resultType: AdminTokenListResult.self
        )
        return result.tokens
    }

    func listCrontabs(token: String) async throws -> [AdminCronRecord] {
        try await call(
            method: "crontab_get",
            params: TokenParams(token: token),
            resultType: [AdminCronRecord].self
        )
    }

    func listKVNamespaces(token: String) async throws -> [String] {
        try await call(
            method: "kv_list_all_namespace",
            params: TokenParams(token: token),
            resultType: [String].self
        )
    }

    func listKVEntries(token: String, namespace: String) async throws -> [KVValueRow] {
        try await call(
            method: "kv_get_multi_value",
            params: KVGetMultiParams(
                token: token,
                namespaceKey: [NamespaceKey(namespace: namespace, key: "*")]
            ),
            resultType: [KVValueRow].self
        )
    }

    func listJSWorkers(token: String) async throws -> [String] {
        try await call(
            method: "js-worker_list_all_js_worker",
            params: TokenParams(token: token),
            resultType: [String].self
        )
    }
}

public struct AdminTokenListResult: Decodable, Equatable {
    public let tokens: [AdminToken]
}

public struct AdminToken: Decodable, Equatable, Identifiable {
    public var id: String { tokenKey }

    public let version: Int?
    public let tokenKey: String
    public let timestampFrom: Int64?
    public let timestampTo: Int64?
    public let tokenLimit: [JSONValue]
    public let username: String?

    enum CodingKeys: String, CodingKey {
        case version
        case tokenKey = "token_key"
        case timestampFrom = "timestamp_from"
        case timestampTo = "timestamp_to"
        case tokenLimit = "token_limit"
        case username
    }

    public var displayName: String {
        let cleanUser = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return cleanUser.isEmpty ? shortToken : cleanUser
    }

    public var shortToken: String {
        guard tokenKey.count > 12 else { return tokenKey }
        return String(tokenKey.prefix(6)) + "…" + String(tokenKey.suffix(4))
    }

    public var limitCount: Int { tokenLimit.count }
}

public struct AdminCronRecord: Decodable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let enable: Bool
    public let cronExpression: String
    public let cronType: JSONValue?
    public let lastRunTime: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case enable
        case cronExpression = "cron_expression"
        case cronType = "cron_type"
        case lastRunTime = "last_run_time"
    }

    public var statusText: String { enable ? "启用" : "停用" }

    public var typeText: String {
        guard let cronType else { return "未知" }
        if case .object(let object) = cronType {
            if object.keys.contains("agent") { return "Agent 任务" }
            if object.keys.contains("server") { return "Server 任务" }
        }
        return "任务"
    }
}
