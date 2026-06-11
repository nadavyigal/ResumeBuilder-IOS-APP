import XCTest
@testable import ResumeBuilder_IOS_APP

final class KeychainStoreTests: XCTestCase {
    private let service = "com.resumebuilder.tests.keychain"
    private let account = "roundtrip"

    override func tearDown() {
        KeychainStore.shared.remove(service: service, account: account)
        super.tearDown()
    }

    func testSaveReadRoundTrip() throws {
        let payload = Data("session-payload".utf8)
        try KeychainStore.shared.save(payload, service: service, account: account)
        XCTAssertEqual(KeychainStore.shared.read(service: service, account: account), payload)
    }

    func testSaveUsesThisDeviceOnlyAccessibility() throws {
        let payload = Data("secure".utf8)
        try KeychainStore.shared.save(payload, service: service, account: account)
        let accessible = KeychainStore.shared.accessibilityAttribute(service: service, account: account)
        XCTAssertEqual(accessible, (kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String))
    }
}
