import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import Networking

@Test func networkChatRepositoryEncodesMessageQueryExactly() async throws {
  let recorder = ChatRequestRecorder()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await recorder.record(request)
    return APIResponse(data: Data(ChatWireFixture.messagesResponse.utf8), statusCode: 200)
  }
  let repository = NetworkChatRepository(
    apiClient: client,
    session: ChatSessionStub(),
    uploader: OSSPartUploader()
  )

  let page = try await repository.fetchMessages(
    in: ChatWireFixture.conversationID,
    query: ChatMessageQuery.after(seq: 41, limit: 100)
  )

  #expect(page.messages.count == 2)
  #expect(page.otherLastRead?.seq == 40)
  #expect(page.hasMore)
  let request = try #require(await recorder.requests().first)
  #expect(request.httpMethod == "GET")
  #expect(
    request.url?.absoluteString
      == "https://api.test/conversations/\(ChatWireFixture.conversationID.uuidString)/messages"
      + "?since_seq=41&limit=100"
  )
  #expect(request.value(forHTTPHeaderField: "authorization") == "Bearer chat-token")
}

@Test func networkChatRepositoryEncodesBeforeAndLatestQueriesExactly() async throws {
  let recorder = ChatRequestRecorder()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await recorder.record(request)
    return APIResponse(data: Data(ChatWireFixture.messagesResponse.utf8), statusCode: 200)
  }
  let repository = NetworkChatRepository(
    apiClient: client,
    session: ChatSessionStub(),
    uploader: OSSPartUploader()
  )

  _ = try await repository.fetchMessages(
    in: ChatWireFixture.conversationID,
    query: ChatMessageQuery.before(seq: 41, limit: 30)
  )
  _ = try await repository.fetchMessages(
    in: ChatWireFixture.conversationID,
    query: ChatMessageQuery.latest(limit: 30)
  )

  let requests = await recorder.requests()
  try #require(requests.count == 2)
  #expect(requests[0].url?.query() == "before_seq=41&limit=30")
  #expect(requests[1].url?.query() == "limit=30")
}

@Test func networkChatRepositoryEncodesOpenTextAndReadRequests() async throws {
  let recorder = ChatRequestRecorder()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await recorder.record(request)
    let path = request.url?.path() ?? ""
    if path.hasSuffix("/read") {
      return APIResponse(data: Data(ChatWireFixture.readResponse.utf8), statusCode: 200)
    }
    if path.hasSuffix("/messages") {
      return APIResponse(data: textMessageResponse(), statusCode: 201)
    }
    return APIResponse(data: Data(ChatWireFixture.conversationResponse.utf8), statusCode: 200)
  }
  let repository = NetworkChatRepository(
    apiClient: client,
    session: ChatSessionStub(),
    uploader: OSSPartUploader()
  )

  _ = try await repository.openConversation(withOtherParty: ChatWireFixture.otherUserID)
  _ = try await repository.sendText(
    in: ChatWireFixture.conversationID,
    text: "明天加重量",
    clientID: "cli-send"
  )
  let read = try await repository.markRead(
    in: ChatWireFixture.conversationID,
    upTo: ChatWireFixture.imageMessageID
  )

  #expect(read.myLastRead.seq == 41)
  #expect(read.unreadCount == 1)
  let requests = await recorder.requests()
  try #require(requests.count == 3)
  let openBody = try jsonBody(requests[0])
  #expect(openBody.count == 1)
  #expect(openBody["other_user_id"] as? String == ChatWireFixture.otherUserID.uuidString)
  let textBody = try jsonBody(requests[1])
  #expect(textBody.count == 3)
  #expect(textBody["kind"] as? String == "text")
  #expect(textBody["body"] as? String == "明天加重量")
  #expect(textBody["client_id"] as? String == "cli-send")
  let readBody = try jsonBody(requests[2])
  #expect(readBody.count == 1)
  #expect(readBody["message_id"] as? String == ChatWireFixture.imageMessageID.uuidString)
}

@Test func networkChatRepositoryMapsBackendChatErrors() async throws {
  let cases: [ChatErrorMappingCase] = [
    ChatErrorMappingCase(
      statusCode: 403, machineCode: "CHAT_BIND_REQUIRED", expected: .bindRequired),
    ChatErrorMappingCase(
      statusCode: 404,
      machineCode: "CONVERSATION_NOT_FOUND",
      expected: .conversationNotFound
    ),
    ChatErrorMappingCase(
      statusCode: 400,
      machineCode: "CHAT_INVALID_ATTACHMENT",
      expected: .invalidAttachment
    ),
  ]

  for testCase in cases {
    let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { _ in
      APIResponse(
        data: Data(#"{"error":"\#(testCase.machineCode)"}"#.utf8),
        statusCode: testCase.statusCode
      )
    }
    let repository = NetworkChatRepository(
      apiClient: client,
      session: ChatSessionStub(),
      uploader: OSSPartUploader()
    )

    do {
      _ = try await repository.openConversation(withOtherParty: ChatWireFixture.otherUserID)
      Issue.record("Expected \(testCase.machineCode) to throw")
    } catch let error as ChatRepositoryError {
      #expect(error == testCase.expected)
    }
  }
}

private struct ChatSessionStub: SessionStateReader {
  func accessToken() async throws -> String {
    "chat-token"
  }

  func currentUser() async throws -> User {
    throw SessionStateReaderError.missingCurrentUser
  }
}

private struct ChatErrorMappingCase: Sendable {
  let statusCode: Int
  let machineCode: String
  let expected: ChatRepositoryError
}

private actor ChatRequestRecorder {
  private var capturedRequests: [URLRequest] = []

  func record(_ request: URLRequest) {
    capturedRequests.append(request)
  }

  func requests() -> [URLRequest] {
    capturedRequests
  }
}

private func jsonBody(_ request: URLRequest) throws -> [String: Any] {
  let data = try #require(request.httpBody)
  return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func textMessageResponse() -> Data {
  Data(
    """
    {
      "message": {
        "id": "\(ChatWireFixture.textMessageID.uuidString)",
        "conversation_id": "\(ChatWireFixture.conversationID.uuidString)",
        "seq": 43,
        "sender_id": "\(ChatWireFixture.otherUserID.uuidString)",
        "kind": "text",
        "body": "明天加重量",
        "attachment_id": null,
        "image_url": null,
        "image_expires_in": null,
        "client_id": "cli-send",
        "created_at": "2026-07-20T09:13:00.000Z"
      }
    }
    """.utf8
  )
}
