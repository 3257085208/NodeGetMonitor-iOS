import Foundation

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

        let decoded = try JSONDecoder().decode(JSONRPCResponse<Result>.self, from: data)

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
}

public enum NodeGetClientError: Error, Equatable, LocalizedError {
    case invalidHTTPResponse
    case httpStatus(Int)
    case emptyResult

    public var errorDescription: String? {
        switch self {
        case .invalidHTTPResponse:
            return "Invalid HTTP response."
        case .httpStatus(let code):
            return "HTTP status code: \(code)."
        case .emptyResult:
            return "The server returned an empty result."
        }
    }
}
