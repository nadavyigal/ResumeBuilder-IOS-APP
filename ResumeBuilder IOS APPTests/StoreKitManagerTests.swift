import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class StoreKitManagerTests: XCTestCase {
    func testPurchaseRejectsUnknownProductID() async {
        let manager = StoreKitManager()
        do {
            _ = try await manager.purchase(productID: "not_a_real_product")
            XCTFail("Expected invalidProductID")
        } catch StoreKitManagerError.invalidProductID {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
