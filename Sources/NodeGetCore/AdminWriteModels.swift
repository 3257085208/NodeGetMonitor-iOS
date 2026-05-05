import Foundation

public extension NodeGetClient {
    func createToken(
        fatherToken: String,
        username: String?,
        password: String?,
        tokenLimit: [JSONValue],
        timestampFrom: Int64? = nil,
        timestampTo: Int64? = nil
    ) async throws -> TokenCreateResult {
        try await call(
            method: "token_create",
            params: TokenCreateParams(
                fatherToken: fatherToken,
                tokenCreation: TokenCreationRequest(
                    username: username?.nilIfEmpty,
                    password: password?.nilIfEmpty,
                    timestampFrom: timestampFrom,
                    timestampTo: timestampTo,
                    version: 1,
                    tokenLimit: tokenLimit
                )
            ),
            resultType: TokenCreateResult.self
        )
    }

    func deleteToken(token: String, targetToken: String) async throws -> DeleteTokenResult {
        try await call(
            method: "token_delete",
            params: TokenDeleteParams(token: token, targetToken: targetToken),
            resultType: DeleteTokenResult.self
        )
    }

    func editTokenLimit(token: String, targetToken: String, limit: [JSONValue]) async throws -> GenericSuccessResult {
        try await call(
            method: "token_edit",
            params: TokenEditParams(token: token, targetToken: targetToken, limit: limit),
            resultType: GenericSuccessResult.self
        )
    }

    func createCrontab(token: String, name: String, cronExpression: String, cronType: JSONValue) async throws -> IDResult {
        try await call(
            method: "crontab_create",
            params: CrontabWriteParams(token: token, name: name, cronExpression: cronExpression, cronType: cronType),
            resultType: IDResult.self
        )
    }

    func editCrontab(token: String, name: String, cronExpression: String, cronType: JSONValue) async throws -> GenericSuccessResult {
        try await call(
            method: "crontab_edit",
            params: CrontabWriteParams(token: token, name: name, cronExpression: cronExpression, cronType: cronType),
            resultType: GenericSuccessResult.self
        )
    }

    func deleteCrontab(token: String, name: String) async throws -> GenericSuccessResult {
        try await call(
            method: "crontab_delete",
            params: NameTokenParams(token: token, name: name),
            resultType: GenericSuccessResult.self
        )
    }

    func setCrontabEnable(token: String, name: String, enable: Bool) async throws -> GenericSuccessResult {
        try await call(
            method: "crontab_set_enable",
            params: CrontabEnableParams(token: token, name: name, enable: enable),
            resultType: GenericSuccessResult.self
        )
    }

    func createKVNamespace(token: String, namespace: String) async throws -> KVNamespaceCreateResult {
        try await call(
            method: "kv_create",
            params: NamespaceTokenParams(token: token, namespace: namespace),
            resultType: KVNamespaceCreateResult.self
        )
    }

    func setKVValue(token: String, namespace: String, key: String, value: JSONValue) async throws -> GenericSuccessResult {
        try await call(
            method: "kv_set_value",
            params: KVSetValueParams(token: token, namespace: namespace, key: key, value: value),
            resultType: GenericSuccessResult.self
        )
    }

    func deleteKVKey(token: String, namespace: String, key: String) async throws -> GenericSuccessResult {
        try await call(
            method: "kv_delete_key",
            params: KVKeyParams(token: token, namespace: namespace, key: key),
            resultType: GenericSuccessResult.self
        )
    }

    func deleteKVNamespace(token: String, namespace: String) async throws -> GenericSuccessResult {
        try await call(
            method: "kv_delete_namespace",
            params: NamespaceTokenParams(token: token, namespace: namespace),
            resultType: GenericSuccessResult.self
        )
    }

    func getKVAllKeys(token: String, namespace: String) async throws -> [String] {
        try await call(
            method: "kv_get_all_keys",
            params: NamespaceTokenParams(token: token, namespace: namespace),
            resultType: [String].self
        )
    }

    func readJSWorker(token: String, name: String) async throws -> JSWorkerRecord {
        try await call(
            method: "js-worker_read",
            params: NameTokenParams(token: token, name: name),
            resultType: JSWorkerRecord.self
        )
    }

    func createJSWorker(
        token: String,
        name: String,
        description: String?,
        jsScriptBase64: String,
        routeName: String?,
        runtimeCleanTime: Int?,
        env: JSONValue?
    ) async throws -> JSWorkerMutationResult {
        try await call(
            method: "js-worker_create",
            params: JSWorkerWriteParams(
                token: token,
                name: name,
                description: description?.nilIfEmpty,
                jsScriptBase64: jsScriptBase64,
                routeName: routeName?.nilIfEmpty,
                runtimeCleanTime: runtimeCleanTime,
                env: env ?? .object([:])
            ),
            resultType: JSWorkerMutationResult.self
        )
    }

    func updateJSWorker(
        token: String,
        name: String,
        description: String?,
        jsScriptBase64: String,
        routeName: String?,
        runtimeCleanTime: Int?,
        env: JSONValue?
    ) async throws -> JSWorkerMutationResult {
        try await call(
            method: "js-worker_update",
            params: JSWorkerWriteParams(
                token: token,
                name: name,
                description: description?.nilIfEmpty,
                jsScriptBase64: jsScriptBase64,
                routeName: routeName?.nilIfEmpty,
                runtimeCleanTime: runtimeCleanTime,
                env: env ?? .object([:])
            ),
            resultType: JSWorkerMutationResult.self
        )
    }

    func deleteJSWorker(token: String, name: String) async throws -> GenericSuccessResult {
        try await call(
            method: "js-worker_delete",
            params: NameTokenParams(token: token, name: name),
            resultType: GenericSuccessResult.self
        )
    }

    func runJSWorker(token: String, name: String, params: JSONValue, env: JSONValue? = nil, compileMode: String = "bytecode") async throws -> IDResult {
        try await call(
            method: "js-worker_run",
            params: JSWorkerRunParams(token: token, jsScriptName: name, runType: "call", params: params, env: env, compileMode: compileMode),
            resultType: IDResult.self
        )
    }
}

public struct GenericSuccessResult: Decodable, Equatable {
    public let success: Bool?
    public let id: Int?
    public let tokenKey: String?
    public let name: String?
    public let rowsAffected: Int?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case id
        case tokenKey = "token_key"
        case name
        case rowsAffected = "rows_affected"
        case message
    }
}

public struct IDResult: Decodable, Equatable { public let id: Int }

public struct TokenCreateResult: Decodable, Equatable {
    public let key: String
    public let secret: String
    public var fullToken: String { "\(key):\(secret)" }
}

public struct DeleteTokenResult: Decodable, Equatable {
    public let message: String?
    public let rowsAffected: Int?
    public let matchedBy: String?

    enum CodingKeys: String, CodingKey {
        case message
        case rowsAffected = "rows_affected"
        case matchedBy = "matched_by"
    }
}

public struct TokenCreateParams: Encodable, Equatable {
    public let fatherToken: String
    public let tokenCreation: TokenCreationRequest
    enum CodingKeys: String, CodingKey { case fatherToken = "father_token"; case tokenCreation = "token_creation" }
}

public struct TokenCreationRequest: Encodable, Equatable {
    public let username: String?
    public let password: String?
    public let timestampFrom: Int64?
    public let timestampTo: Int64?
    public let version: Int
    public let tokenLimit: [JSONValue]
    enum CodingKeys: String, CodingKey {
        case username
        case password
        case timestampFrom = "timestamp_from"
        case timestampTo = "timestamp_to"
        case version
        case tokenLimit = "token_limit"
    }
}

public struct TokenDeleteParams: Encodable, Equatable {
    public let token: String
    public let targetToken: String
    enum CodingKeys: String, CodingKey { case token; case targetToken = "target_token" }
}

public struct TokenEditParams: Encodable, Equatable {
    public let token: String
    public let targetToken: String
    public let limit: [JSONValue]
    enum CodingKeys: String, CodingKey { case token; case targetToken = "target_token"; case limit }
}

public struct CrontabWriteParams: Encodable, Equatable {
    public let token: String
    public let name: String
    public let cronExpression: String
    public let cronType: JSONValue
    enum CodingKeys: String, CodingKey { case token; case name; case cronExpression = "cron_expression"; case cronType = "cron_type" }
}

public struct CrontabEnableParams: Encodable, Equatable {
    public let token: String
    public let name: String
    public let enable: Bool
}

public struct NameTokenParams: Encodable, Equatable {
    public let token: String
    public let name: String
}

public struct NamespaceTokenParams: Encodable, Equatable {
    public let token: String
    public let namespace: String
}

public struct KVKeyParams: Encodable, Equatable {
    public let token: String
    public let namespace: String
    public let key: String
}

public struct KVSetValueParams: Encodable, Equatable {
    public let token: String
    public let namespace: String
    public let key: String
    public let value: JSONValue
}

public struct KVNamespaceCreateResult: Decodable, Equatable {
    public let id: Int?
    public let namespace: String?
}

public struct JSWorkerRecord: Decodable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String
    public let description: String?
    public let routeName: String?
    public let jsScriptBase64: String?
    public let runtimeCleanTime: Int?
    public let env: JSONValue?
    public let createAt: Int64?
    public let updateAt: Int64?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case routeName = "route_name"
        case jsScriptBase64 = "js_script_base64"
        case runtimeCleanTime = "runtime_clean_time"
        case env
        case createAt = "create_at"
        case updateAt = "update_at"
    }
}

public struct JSWorkerWriteParams: Encodable, Equatable {
    public let token: String
    public let name: String
    public let description: String?
    public let jsScriptBase64: String
    public let routeName: String?
    public let runtimeCleanTime: Int?
    public let env: JSONValue
    enum CodingKeys: String, CodingKey {
        case token
        case name
        case description
        case jsScriptBase64 = "js_script_base64"
        case routeName = "route_name"
        case runtimeCleanTime = "runtime_clean_time"
        case env
    }
}

public struct JSWorkerMutationResult: Decodable, Equatable {
    public let id: Int?
    public let name: String?
    public let description: String?
    public let routeName: String?
    public let success: Bool?
    enum CodingKeys: String, CodingKey { case id; case name; case description; case routeName = "route_name"; case success }
}

public struct JSWorkerRunParams: Encodable, Equatable {
    public let token: String
    public let jsScriptName: String
    public let runType: String
    public let params: JSONValue
    public let env: JSONValue?
    public let compileMode: String
    enum CodingKeys: String, CodingKey {
        case token
        case jsScriptName = "js_script_name"
        case runType = "run_type"
        case params
        case env
        case compileMode = "compile_mode"
    }
}

