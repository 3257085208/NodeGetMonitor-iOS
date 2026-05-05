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
}
