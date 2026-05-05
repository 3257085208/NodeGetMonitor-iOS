import Foundation

public struct JSONRPCRequest<Params: Encodable>: Encodable {
    public let jsonrpc: String
    public let method: String
    public let params: Params
    public let id: Int

    public init(method: String, params: Params, id: Int) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
        self.id = id
    }
}

public struct JSONRPCResponse<Result: Decodable>: Decodable {
    public let jsonrpc: String?
    public let result: Result?
    public let error: JSONRPCError?
    public let id: Int?

    public init(jsonrpc: String?, result: Result?, error: JSONRPCError?, id: Int?) {
        self.jsonrpc = jsonrpc
        self.result = result
        self.error = error
        self.id = id
    }
}

public struct JSONRPCError: Decodable, Error, Equatable, LocalizedError {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    public var errorDescription: String? {
        "JSON-RPC error \(code): \(message)"
    }
}

public struct EmptyParams: Encodable {
    public init() {}
}
