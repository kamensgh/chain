import Foundation
import Testing
@testable import ChainDomain

struct KeychainHelperTests {

    func key() -> String { "chain.test.\(UUID().uuidString)" }

    @Test func saveAndLoad() {
        let k = key()
        KeychainHelper.save("secret", for: k)
        #expect(KeychainHelper.load(for: k) == "secret")
        KeychainHelper.delete(for: k)
    }

    @Test func loadMissingReturnsNil() {
        #expect(KeychainHelper.load(for: "chain.test.missing.\(UUID().uuidString)") == nil)
    }

    @Test func deleteRemovesValue() {
        let k = key()
        KeychainHelper.save("token", for: k)
        KeychainHelper.delete(for: k)
        #expect(KeychainHelper.load(for: k) == nil)
    }

    @Test func overwriteUpdatesValue() {
        let k = key()
        KeychainHelper.save("old", for: k)
        KeychainHelper.save("new", for: k)
        #expect(KeychainHelper.load(for: k) == "new")
        KeychainHelper.delete(for: k)
    }
}
