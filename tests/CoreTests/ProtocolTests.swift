import XCTest
#if SWIFT_PACKAGE
@testable import AIWristCore
#endif

@MainActor
final class ProtocolTests: XCTestCase {
    func testRoundTripContractAndTenMockReplies() async throws {
        let router = CompanionLLMRouter(provider: FakeProvider())
        for _ in 0..<10 {
            let query = try WatchQuery(text: " 測試繁體中文 ")
            let decoded = try WatchQuery(message: query.message)
            XCTAssertEqual(query, decoded)
            let answer = try await router.query(decoded)
            let reply = WatchReply(requestID: query.requestID, result: .success(answer))
            XCTAssertEqual(try WatchReply.decode(reply.message, for: query.requestID), "iPhone 已收到你的訊息")
        }
    }
    func testRejectsMalformedRequests() throws {
        for text in ["", " \n", String(repeating: "字", count: 4001)] {
            XCTAssertThrowsError(try WatchQuery(text: text))
        }
        XCTAssertThrowsError(try WatchQuery(text: "hi", requestID: "bad"))
        XCTAssertThrowsError(try WatchQuery(text: "hi", locale: "en"))
        XCTAssertThrowsError(try WatchQuery(message: ["type": "query"]))
    }
    func testCorrelatesErrorAndSuccessReplies() throws {
        let id = UUID().uuidString
        XCTAssertThrowsError(try WatchReply.decode(["request_id": "other", "error": "bad"], for: id))
        XCTAssertThrowsError(try WatchReply.decode(["request_id": id, "reply": " "], for: id))
        XCTAssertThrowsError(try WatchReply.decode(["request_id": id, "error": "failed"], for: id))
    }
    func testFailureProvider() async throws {
        do {
            _ = try await CompanionLLMRouter(provider: FakeProvider(mode: .failure)).query(WatchQuery(text: "test"))
            XCTFail("Expected failure")
        } catch { XCTAssertTrue(error.localizedDescription.contains("provider")) }
    }
    func testLatchKeepsFirstResultAcrossRacingCallbacks() async throws {
        let latch = ReplyLatch()
        let result = try await withCheckedThrowingContinuation { continuation in
            latch.install(continuation)
            latch.finish(.success("first"))
            latch.finish(.failure(ProtocolError.timeout))
            latch.finish(.success("late"))
        }
        XCTAssertEqual(result, "first")
    }
    func testCancellationBeforeContinuationInstallation() async {
        let latch = ReplyLatch()
        latch.finish(.failure(CancellationError()))
        do {
            _ = try await withCheckedThrowingContinuation { latch.install($0) }
            XCTFail("Expected cancellation")
        } catch { XCTAssertTrue(error is CancellationError) }
    }
}
