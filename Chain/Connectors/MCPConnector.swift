import Foundation

struct MCPConnector: HabitConnector {
    let endpoint: URL
    let credential: String?
    let session: URLSession

    init(endpoint: URL, credential: String?, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.credential = credential
        self.session = session
    }

    func verify(goalConfig: GoalConfig) async throws -> VerificationResult {
        var request = URLRequest(url: endpoint, timeoutInterval: 10)
        if let token = credential {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw MCPConnectorError.badResponse
        }
        let payload = try JSONDecoder().decode(MCPResponse.self, from: data)
        return VerificationResult(
            status: payload.verified ? .verified : .pending,
            verifMethod: .auto,
            value: payload.value,
            sourceLabel: payload.label ?? endpoint.host ?? "MCP"
        )
    }

}

public enum MCPConnectorError: Swift.Error { case badResponse }

private struct MCPResponse: Decodable {
    let verified: Bool
    let value: Double?
    let label: String?
}
