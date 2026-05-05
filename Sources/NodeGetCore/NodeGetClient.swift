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
        request.timeoutInterval = 15
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
            throw NodeGetClientError.decodingFailed(raw.prefixString(600))
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
        try await call(
            method: "nodeget-server_hello",
            params: EmptyParams(),
            resultType: String.self
        )
    }

    public func serverVersion() async throws -> String {
        try await call(
            method: "nodeget-server_version",
            params: EmptyParams(),
            resultType: String.self
        )
    }

    public func serverUUID() async throws -> String {
        try await call(
            method: "nodeget-server_uuid",
            params: EmptyParams(),
            resultType: String.self
        )
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
            params: AgentDynamicSummaryMultiLastQueryParams(
                token: token,
                uuids: uuids,
                fields: fields
            ),
            resultType: [AgentSummary].self
        )
    }

    public func latestStaticInfo(token: String, uuid: String) async throws -> StaticAgentInfo? {
        let records: [StaticAgentInfo] = try await call(
            method: "agent_query_static",
            params: AgentStaticQueryParams(
                token: token,
                staticDataQuery: StaticDataQuery(
                    fields: ["cpu", "system"],
                    condition: [.uuid(uuid), .last]
                )
            ),
            resultType: [StaticAgentInfo].self
        )
        return records.first
    }
}

public struct AgentUUIDListResult: Decodable, Equatable {
    public let uuids: [String]

    public init(uuids: [String]) {
        self.uuids = uuids
    }
}

public struct TokenParams: Encodable, Equatable {
    public let token: String

    public init(token: String) {
        self.token = token
    }
}

public struct AgentDynamicSummaryMultiLastQueryParams: Encodable, Equatable {
    public let token: String
    public let uuids: [String]
    public let fields: [String]

    public init(token: String, uuids: [String], fields: [String]) {
        self.token = token
        self.uuids = uuids
        self.fields = fields
    }
}

public struct AgentStaticQueryParams: Encodable, Equatable {
    public let token: String
    public let staticDataQuery: StaticDataQuery

    enum CodingKeys: String, CodingKey {
        case token
        case staticDataQuery = "static_data_query"
    }

    public init(token: String, staticDataQuery: StaticDataQuery) {
        self.token = token
        self.staticDataQuery = staticDataQuery
    }
}

public struct StaticDataQuery: Encodable, Equatable {
    public let fields: [String]
    public let condition: [QueryCondition]

    public init(fields: [String], condition: [QueryCondition]) {
        self.fields = fields
        self.condition = condition
    }
}

public enum QueryCondition: Equatable {
    case uuid(String)
    case last
}

extension QueryCondition: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .uuid(let value):
            try container.encode(["uuid": value])
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
