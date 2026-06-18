import XCTest
@testable import ResumeBuilder_IOS_APP

final class JWTDecoderTests: XCTestCase {
    func testShouldRefreshWhenExpiryWithinLeeway() {
        let exp = Date().addingTimeInterval(120).timeIntervalSince1970
        let token = makeJWT(exp: exp)
        XCTAssertTrue(JWTDecoder.shouldRefresh(accessToken: token, leeway: 300))
    }

    func testSkipsRefreshWhenExpiryBeyondLeeway() {
        let exp = Date().addingTimeInterval(900).timeIntervalSince1970
        let token = makeJWT(exp: exp)
        XCTAssertFalse(JWTDecoder.shouldRefresh(accessToken: token, leeway: 300))
    }

    func testExpirationDateParsesPayload() {
        let exp = Date(timeIntervalSince1970: 1_900_000_000)
        let token = makeJWT(exp: exp.timeIntervalSince1970)
        XCTAssertEqual(JWTDecoder.expirationDate(from: token), exp)
    }

    private func makeJWT(exp: TimeInterval) -> String {
        let header = base64URL(Data("{\"alg\":\"none\",\"typ\":\"JWT\"}".utf8))
        let payload = base64URL(Data("{\"exp\":\(Int(exp))}".utf8))
        return "\(header).\(payload).signature"
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
