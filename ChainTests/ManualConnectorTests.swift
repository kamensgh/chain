import Testing
@testable import ChainDomain

struct ManualConnectorTests {

    @Test func verifyReturnsVerifiedStatus() async throws {
        let result = try await ManualConnector().verify(goalConfig: .boolean)
        #expect(result.status == .verified)
    }

    @Test func verifyReturnsManualMethod() async throws {
        let result = try await ManualConnector().verify(goalConfig: .boolean)
        #expect(result.verifMethod == .manual)
    }

    @Test func verifyReturnsNilValue() async throws {
        let result = try await ManualConnector().verify(goalConfig: .boolean)
        #expect(result.value == nil)
    }

    @Test func sourceLabelIsManual() async throws {
        let result = try await ManualConnector().verify(goalConfig: .boolean)
        #expect(result.sourceLabel == "Manual")
    }
}
