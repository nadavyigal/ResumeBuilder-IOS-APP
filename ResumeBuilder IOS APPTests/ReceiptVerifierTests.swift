import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class ReceiptVerifierTests: XCTestCase {
    func testVerifyPurchaseRejectsEmptyTransactionID() async {
        let verifier = ReceiptVerifier()
        do {
            try await verifier.verifyPurchase(productID: "credits_basic", transactionID: "   ", token: "tok")
            XCTFail("Expected invalidPayload")
        } catch ReceiptVerifierError.invalidPayload {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testVerifyPurchaseRejectsUnknownProductID() async {
        let verifier = ReceiptVerifier()
        do {
            try await verifier.verifyPurchase(productID: "unknown_pack", transactionID: "12345", token: "tok")
            XCTFail("Expected invalidProductID")
        } catch ReceiptVerifierError.invalidProductID {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
