import Foundation
import Testing

@testable import Networking

@Suite struct RealtimeEventTests {
  private let conversationID = UUID(uuidString: "00000000-0000-4000-8000-000000000066")
  private let userID = UUID(uuidString: "00000000-0000-4000-8000-000000000067")

  @Test func decodesKnownEvents() throws {
    let conversationID = try #require(conversationID)
    let userID = try #require(userID)
    let messageJSON = """
      {"type":"chat.message","payload":{
        "conversation_id":"\(conversationID.uuidString)","seq":42,
        "sender_id":"\(userID.uuidString)"}}
      """
    let readJSON = """
      {"type":"chat.read","payload":{
        "conversation_id":"\(conversationID.uuidString)",
        "user_id":"\(userID.uuidString)","last_read_seq":41}}
      """

    #expect(RealtimeEvent.decode(Data(#"{"type":"hello","payload":{}}"#.utf8)) == .hello)
    #expect(
      RealtimeEvent.decode(Data(messageJSON.utf8))
        == .chatMessage(conversationID: conversationID, seq: 42, senderID: userID)
    )
    #expect(
      RealtimeEvent.decode(Data(readJSON.utf8))
        == .chatRead(conversationID: conversationID, userID: userID, lastReadSeq: 41)
    )
  }

  @Test func unknownAndMalformedEventsAreSkipped() {
    #expect(
      RealtimeEvent.decode(Data(#"{"type":"future.event","payload":{"version":2}}"#.utf8))
        == nil
    )
    #expect(RealtimeEvent.decode(Data("not-json".utf8)) == nil)
    #expect(
      RealtimeEvent.decode(Data(#"{"type":"chat.message","payload":{"seq":42}}"#.utf8))
        == nil
    )
  }
}
