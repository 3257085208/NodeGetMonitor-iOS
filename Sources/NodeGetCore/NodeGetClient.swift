import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class NodeGetClient {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func call<Params: Encodable, Result: Decodable>(
        method: String,
        params: Params,
        resultType: Result.Type,
        id: Int = Int.random(in: 1...999_999)
    ) async throws -> Result {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let rpcRequest = JSONRPCRequest(method: method, params: params, id: id)
        request.httpBody = try JSONEncoder().encode(rpcRequest)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NodeGetClientError.invalidHTTPResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NodeGetClientError.httpStatus(httpResponse.statusCode)
        }

        let decoded: JSONRPCResponse<Result>
        do {
            decoded = try JSONDecoder().decode(JSONRPCResponse<Result>.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            throw NodeGetClientError.decodingFailed(raw.prefixString(800))
        }

        if let error = decoded.error {
            throw error
        }

        guard let result = decoded.result else {
            throw NodeGetClientError.emptyResult
        }

        return result
    }

    public func hello() async throws -> String {
        try await call(method: "nodeget-server_hello", params: EmptyParams(), resultType: String.self)
    }

    public func listAllAgentUUIDs(token: String) async throws -> [String] {
        let result: AgentUUIDListResult = try await call(
            method: "nodeget-server_list_all_agent_uuid",
            params: TokenParams(token: token),
            resultType: AgentUUIDListResult.self
        )
        return result.uuids
    }

    public func latestDynamicSummaries(
        token: String,
        uuids: [String],
        fields: [String] = AgentSummary.defaultFields
    ) async throws -> [AgentSummary] {
        try await call(
            method: "agent_dynamic_summary_multi_last_query",
            params: AgentDynamicSummaryMultiLastQueryParams(token: token, uuids: uuids, fields: fields),
            resultType: [AgentSummary].self
        )
    }

    public func dynamicSummaryHistory(
        token: String,
        uuid: String,
        limit: Int = 240,
        windowMilliseconds: Int64? = 240_000,
        fields: [String] = AgentSummary.defaultFields
    ) async throws -> [AgentSummary] {
        var conditions: [QueryCondition] = [.uuid(uuid)]
        if let windowMilliseconds {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            conditions.append(.timestampFrom(now - windowMilliseconds))
        }
        conditions.append(.limit(limit))

        let rows: [AgentSummary] = try await call(
            method: "agent_query_dynamic_summary",
            params: AgentDynamicSummaryQueryParams(
                token: token,
                dynamicSummaryQuery: DynamicSummaryQuery(
                    fields: fields,
                    condition: conditions
                )
            ),
            resultType: [AgentSummary].self
        )
        return rows.sorted { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }
    }

    public func dynamicSummaryAverage(
        token: String,
        uuid: String,
        timestampFrom: Int64,
        timestampTo: Int64,
        points: Int = 80,
        fields: [String] = ["cpu_usage", "used_memory", "total_memory", "receive_speed", "transmit_speed"]
    ) async throws -> [AgentSummary] {
        let rows: [AgentSummary] = try await call(
            method: "agent_query_dynamic_summary_avg",
            params: DynamicSummaryAverageQueryParams(
                token: token,
                dynamicSummaryAvgQuery: DynamicSummaryAvgQuery(
                    fields: fields,
                    uuid: uuid,
                    timestampFrom: timestampFrom,
                    timestampTo: timestampTo,
                    points: points
                )
            ),
            resultType: [AgentSummary].self
        )
        return rows.sorted { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }
    }

    public func latestStaticInfoMap(token: String, uuids: [String]) async throws -> [String: StaticAgentInfo] {
        let rows: [StaticAgentInfo] = try await call(
            method: "agent_static_data_multi_last_query",
            params: StaticMultiLastParams(token: token, uuids: uuids, fields: ["cpu", "system", "gpu"]),
            resultType: [StaticAgentInfo].self
        )
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.uuid, $0) })
    }

    public func latestStaticInfo(token: String, uuid: String) async throws -> StaticAgentInfo? {
        let map = try await latestStaticInfoMap(token: token, uuids: [uuid])
        return map[uuid]
    }

    public func metadataMap(token: String, uuids: [String]) async throws -> [String: AgentMeta] {
        let keys = [
            "metadata_name",
            "metadata_region",
            "metadata_tags",
            "metadata_hidden",
            "metadata_virtualization",
            "metadata_price",
            "metadata_price_unit",
            "metadata_price_cycle",
            "metadata_expire_time"
        ]
        let items = uuids.flatMap { uuid in keys.map { NamespaceKey(namespace: uuid, key: $0) } }
        guard !items.isEmpty else { return [:] }

        let rows: [KVValueRow] = try await call(
            method: "kv_get_multi_value",
            params: KVGetMultiParams(token: token, namespaceKey: items),
            resultType: [KVValueRow].self
        )

        var grouped: [String: [String: JSONValue]] = [:]
        for row in rows {
            guard let value = row.value else { continue }
            grouped[row.namespace, default: [:]][row.key] = value
        }

        var result: [String: AgentMeta] = [:]
        for uuid in uuids {
            let raw = grouped[uuid] ?? [:]
            let price = raw["metadata_price"]?.doubleValue ?? 0
            let cycle = Int(raw["metadata_price_cycle"]?.doubleValue ?? 30)
            result[uuid] = AgentMeta(
                name: raw["metadata_name"]?.stringValue ?? "",
                region: raw["metadata_region"]?.stringValue ?? "",
                tags: raw["metadata_tags"]?.stringArrayValue ?? [],
                hidden: raw["metadata_hidden"]?.boolValue ?? false,
                virtualization: raw["metadata_virtualization"]?.stringValue ?? "",
                price: price,
                priceUnit: raw["metadata_price_unit"]?.stringValue ?? "$",
                priceCycle: cycle > 0 ? cycle : 30,
                expireTime: raw["metadata_expire_time"]?.stringValue ?? ""
            )
        }

        return result
    }

    public func taskLatencyRows(
        token: String,
        uuid: String,
        type: String,
        windowMilliseconds: Int64 = 3_600_000,
        limit: Int? = 240
    ) async throws -> [TaskQueryResult] {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        var windowedConditions: [TaskQueryCondition] = [
            .uuid(uuid),
            .timestampFromTo(now - windowMilliseconds, now),
            .type(type)
        ]
        if let limit { windowedConditions.append(.limit(limit)) }

        let windowedRows: [TaskQueryResult] = try await call(
            method: "task_query",
            params: TaskQueryParams(
                token: token,
                taskDataQuery: TaskDataQuery(condition: windowedConditions)
            ),
            resultType: [TaskQueryResult].self
        )

        if !windowedRows.isEmpty {
            return windowedRows.sorted { $0.timestamp < $1.timestamp }
        }

        var fallbackConditions: [TaskQueryCondition] = [.uuid(uuid), .type(type)]
        if let limit { fallbackConditions.append(.limit(limit)) }

        let fallbackRows: [TaskQueryResult] = try await call(
            method: "task_query",
            params: TaskQueryParams(
                token: token,
                taskDataQuery: TaskDataQuery(condition: fallbackConditions)
            ),
            resultType: [TaskQueryResult].self
        )
        return fallbackRows.sorted { $0.timestamp < $1.timestamp }
    }
}

public struct AgentUUIDListResult: Decodable, Equatable {
    public let uuids: [String]
}

public struct TokenParams: Encodable, Equatable {
    public let token: String
}

public struct AgentDynamicSummaryMultiLastQueryParams: Encodable, Equatable {
    public let token: String
    public let uuids: [String]
    public let fields: [String]
}

public struct StaticMultiLastParams: Encodable, Equatable {
    public let token: String
    public let uuids: [String]
    public let fields: [String]
}

public struct AgentStaticQueryParams: Encodable, Equatable {
    public let token: String
    public let staticDataQuery: StaticDataQuery

    enum CodingKeys: String, CodingKey {
        case token
        case staticDataQuery = "static_data_query"
    }
}

public struct StaticDataQuery: Encodable, Equatable {
    public let fields: [String]
    public let condition: [QueryCondition]
}

public struct AgentDynamicSummaryQueryParams: Encodable, Equatable {
    public let token: String
    public let dynamicSummaryQuery: DynamicSummaryQuery

    enum CodingKeys: String, CodingKey {
        case token
        case dynamicSummaryQuery = "dynamic_summary_query"
    }
}

public struct DynamicSummaryQuery: Encodable, Equatable {
    public let fields: [String]
    public let condition: [QueryCondition]
}

public struct DynamicSummaryAverageQueryParams: Encodable, Equatable {
    public let token: String
    public let dynamicSummaryAvgQuery: DynamicSummaryAvgQuery

    enum CodingKeys: String, CodingKey {
        case token
        case dynamicSummaryAvgQuery = "dynamic_summary_avg_query"
    }
}

public struct DynamicSummaryAvgQuery: Encodable, Equatable {
    public let fields: [String]
    public let uuid: String
    public let timestampFrom: Int64
    public let timestampTo: Int64
    public let points: Int

    enum CodingKeys: String, CodingKey {
        case fields
        case uuid
        case timestampFrom = "timestamp_from"
        case timestampTo = "timestamp_to"
        case points
    }
}

public struct NamespaceKey: Encodable, Equatable {
    public let namespace: String
    public let key: String
}

public struct KVGetMultiParams: Encodable, Equatable {
    public let token: String
    public let namespaceKey: [NamespaceKey]

    enum CodingKeys: String, CodingKey {
        case token
        case namespaceKey = "namespace_key"
    }
}

public struct TaskQueryParams: Encodable, Equatable {
    public let token: String
    public let taskDataQuery: TaskDataQuery

    enum CodingKeys: String, CodingKey {
        case token
        case taskDataQuery = "task_data_query"
    }
}

public struct TaskDataQuery: Encodable, Equatable {
    public let condition: [TaskQueryCondition]
}

public enum QueryCondition: Equatable {
    case uuid(String)
    case timestampFromTo(Int64, Int64)
    case timestampFrom(Int64)
    case timestampTo(Int64)
    case limit(Int)
    case last
}

extension QueryCondition: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .uuid(let value):
            try container.encode(["uuid": value])
        case .timestampFromTo(let from, let to):
            try container.encode(["timestamp_from_to": [from, to]])
        case .timestampFrom(let value):
            try container.encode(["timestamp_from": value])
        case .timestampTo(let value):
            try container.encode(["timestamp_to": value])
        case .limit(let value):
            try container.encode(["limit": value])
        case .last:
            try container.encode("last")
        }
    }
}

public enum TaskQueryCondition: Equatable {
    case uuid(String)
    case timestampFromTo(Int64, Int64)
    case type(String)
    case cronSource(String)
    case limit(Int)
    case last
}

extension TaskQueryCondition: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .uuid(let value):
            try container.encode(["uuid": value])
        case .timestampFromTo(let from, let to):
            try container.encode(["timestamp_from_to": [from, to]])
        case .type(let value):
            try container.encode(["type": value])
        case .cronSource(let value):
            try container.encode(["cron_source": value])
        case .limit(let value):
            try container.encode(["limit": value])
        case .last:
            try container.encode("last")
        }
    }
}

public enum NodeGetClientError: Error, Equatable, LocalizedError {
    case invalidHTTPResponse
    case httpStatus(Int)
    case emptyResult
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidHTTPResponse:
            return "Invalid HTTP response."
        case .httpStatus(let code):
            return "HTTP status code: \(code)."
        case .emptyResult:
            return "The server returned an empty result."
        case .decodingFailed(let raw):
            return "Response decoding failed. Raw response: \(raw)"
        }
    }
}

private extension StringProtocol {
    func prefixString(_ maxLength: Int) -> String {
        let truncated = self.prefix(maxLength)
        return String(truncated)
    }
}
