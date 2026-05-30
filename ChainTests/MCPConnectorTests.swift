// ChainTests/MCPConnectorTests.swift
import Testing
import Foundation
@testable import ChainDomain

final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubURLProtocol.handler, let url = request.url else { return }
        let (data, response) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct MCPConnectorTests {

    let stubConfig: URLSessionConfiguration = {
        let c = URLSessionConfiguration.ephemeral
        c.protocolClasses = [StubURLProtocol.self]
        return c
    }()

    func makeConnector(endpoint: String = "http://test.local/verify", credential: String? = nil) -> MCPConnector {
        let session = URLSession(configuration: stubConfig)
        return MCPConnector(endpoint: URL(string: endpoint)!, credential: credential, session: session)
    }

    func stub(_ json: String, status: Int = 200) {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(json.utf8), response)
        }
    }

    @Test func verifiedTrueReturnsVerified() async throws {
        stub(#"{"verified":true,"value":8432,"label":"8,432 steps"}"#)
        let result = try await makeConnector().verify(goalConfig: .boolean)
        #expect(result.status == .verified)
        #expect(result.value == 8432)
        #expect(result.sourceLabel == "8,432 steps")
        #expect(result.verifMethod == .auto)
    }

    @Test func verifiedFalseReturnsPending() async throws {
        stub(#"{"verified":false}"#)
        let result = try await makeConnector().verify(goalConfig: .boolean)
        #expect(result.status == .pending)
        #expect(result.value == nil)
    }

    @Test func labelFallsBackToHostWhenAbsent() async throws {
        stub(#"{"verified":true}"#)
        let result = try await makeConnector(endpoint: "http://myserver.local/check").verify(goalConfig: .boolean)
        #expect(result.sourceLabel == "myserver.local")
    }

    @Test func badStatusThrows() async {
        stub("", status: 500)
        await #expect(throws: MCPConnectorError.badResponse) {
            try await makeConnector().verify(goalConfig: .boolean)
        }
    }

    @Test func bearerTokenSentInHeader() async throws {
        var captured: URLRequest?
        StubURLProtocol.handler = { req in
            captured = req
            let res = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(#"{"verified":true}"#.utf8), res)
        }
        _ = try await makeConnector(credential: "my-token").verify(goalConfig: .boolean)
        #expect(captured?.value(forHTTPHeaderField: "Authorization") == "Bearer my-token")
    }

    @Test func noCredentialSendsNoAuthHeader() async throws {
        var captured: URLRequest?
        StubURLProtocol.handler = { req in
            captured = req
            let res = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(#"{"verified":true}"#.utf8), res)
        }
        _ = try await makeConnector(credential: nil).verify(goalConfig: .boolean)
        #expect(captured?.value(forHTTPHeaderField: "Authorization") == nil)
    }
}
