import XCTest
@testable import NodeGetCore

final class NodeGetCoreTests: XCTestCase {
    func testJSONRPCRequestEncoding() throws {
        let request = JSONRPCRequest(
            method: "nodeget-server_hello",
            params: EmptyParams(),
            id: 1
        )

        let data = try JSONEncoder().encode(request)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertTrue(json.contains("\"jsonrpc\":\"2.0\""))
        XCTAssertTrue(json.contains("\"method\":\"nodeget-server_hello\""))
        XCTAssertTrue(json.contains("\"id\":1"))
    }

    func testJSONRPCErrorEquatable() {
        let error = JSONRPCError(code: -32600, message: "Invalid Request")
        XCTAssertEqual(error.code, -32600)
        XCTAssertEqual(error.message, "Invalid Request")
    }

    func testServerProfile() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/"))
        let profile = ServerProfile(name: "Demo Server", baseURL: url)

        XCTAssertEqual(profile.name, "Demo Server")
        XCTAssertEqual(profile.baseURL.absoluteString, "https://example.com/")
    }

    func testByteFormatter() {
        XCTAssertFalse(NodeGetFormatters.bytes(1024).isEmpty)
        XCTAssertEqual(NodeGetFormatters.bytes(nil), "--")
    }

    func testTokenParamsEncoding() throws {
        let params = TokenParams(token: "demo_key:demo_secret")
        let data = try JSONEncoder().encode(params)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertTrue(json.contains("\"token\":\"demo_key:demo_secret\""))
    }

    func testAgentSummaryDecodingSnakeCase() throws {
        let json = """
        {
          "uuid": "agent-1",
          "timestamp": 1760000000000,
          "cpu_usage": 12.5,
          "used_memory": 1024,
          "total_memory": 2048,
          "receive_speed": 100.5,
          "transmit_speed": 20.5,
          "gpu_usage": 5.0
        }
        """.data(using: .utf8)!

        let summary = try JSONDecoder().decode(AgentSummary.self, from: json)

        XCTAssertEqual(summary.uuid, "agent-1")
        XCTAssertEqual(summary.cpuUsage, 12.5)
        XCTAssertEqual(summary.usedMemory, 1024)
        XCTAssertEqual(summary.receiveSpeed, 100.5)
        XCTAssertEqual(summary.gpuUsage, 5.0)
    }
}
