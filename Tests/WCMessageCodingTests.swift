import Foundation
import Testing
@testable import SaferNightCore

@Suite("WCMessageCoding")
struct WCMessageCodingTests {

    @Test func buildPayloadSetsTypeKey() {
        let msg = WCMessageCoding.buildPayload(type: .drinksAdded)
        #expect(msg["t"] as? String == "da")
        #expect(msg["p"] == nil)
    }

    @Test func buildPayloadEncodesDataAsBase64() {
        let data = "hello".data(using: .utf8)!
        let msg = WCMessageCoding.buildPayload(type: .fullContext, data: data)
        #expect(msg["t"] as? String == "fc")
        let b64 = msg["p"] as? String
        #expect(b64 == data.base64EncodedString())
    }

    @Test func decodeRoundTripsCorrectly() {
        let original = ["alpha", "beta", "gamma"]
        let data = try! JSONEncoder().encode(original)
        let msg = WCMessageCoding.buildPayload(type: .drinksDeleted, data: data)
        let decoded: [String]? = WCMessageCoding.decode(from: msg)
        #expect(decoded == original)
    }

    @Test func decodeReturnsNilForMissingPayload() {
        let msg = WCMessageCoding.buildPayload(type: .doneTonight)
        let result: [String]? = WCMessageCoding.decode(from: msg)
        #expect(result == nil)
    }

    @Test func decodeReturnsNilForInvalidBase64() {
        let msg: [String: Any] = ["t": "da", "p": "!!!not-base64!!!"]
        let result: [String]? = WCMessageCoding.decode(from: msg)
        #expect(result == nil)
    }

    @Test func parseTypeReturnsCorrectEnum() {
        for msgType in [WCMsgType.drinksAdded, .drinksDeleted, .profileUpdated,
                        .doneTonight, .contextRequest, .fullContext, .clearAll] {
            let msg: [String: Any] = ["t": msgType.rawValue]
            #expect(WCMessageCoding.parseType(from: msg) == msgType)
        }
    }

    @Test func parseTypeReturnsNilForUnknownType() {
        let msg: [String: Any] = ["t": "xx"]
        #expect(WCMessageCoding.parseType(from: msg) == nil)
    }

    @Test func parseTypeReturnsNilForMissingKey() {
        let msg: [String: Any] = ["other": "value"]
        #expect(WCMessageCoding.parseType(from: msg) == nil)
    }
}
