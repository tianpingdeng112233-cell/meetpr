import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import Networking

@Test func networkChatRepositoryUploadsJPEGThenSendsImage() async throws {
  let recorder = ImageChatRequestRecorder()
  let uploadRecorder = ChatPartUploadRecorder()
  let uploader = OSSPartUploader { request, data in
    await uploadRecorder.record(request: request, data: data)
    return OSSPartUploadResponse(statusCode: 200, headers: ["ETag": #""etag-chat""#])
  }
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await recorder.record(request)
    return imagePipelineResponse(
      request: request, returnedAttachmentID: ChatWireFixture.attachmentID)
  }
  let repository = imageRepository(client: client, uploader: uploader)
  let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])

  let message = try await repository.sendImage(
    in: ChatWireFixture.conversationID,
    imageData: jpeg,
    clientID: "cli-image"
  )

  #expect(message.attachmentID == ChatWireFixture.attachmentID)
  #expect(message.clientID == "cli-image")
  let uploaded = try #require(await uploadRecorder.upload)
  #expect(uploaded.request.httpMethod == "PUT")
  #expect(uploaded.request.url?.absoluteString == "https://oss.example.test/chat?partNumber=1")
  #expect(uploaded.data == jpeg)
  try assertImagePipelineRequests(await recorder.requests(), jpegCount: jpeg.count)
}

@Test func networkChatRepositoryDeletesNewAttachmentOnIdempotentOldMessage() async throws {
  let recorder = ImageChatRequestRecorder()
  let oldAttachmentID = imageTestUUID(30)
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await recorder.record(request)
    return imagePipelineResponse(request: request, returnedAttachmentID: oldAttachmentID)
  }
  let repository = imageRepository(client: client)

  let message = try await repository.sendImage(
    in: ChatWireFixture.conversationID,
    imageData: Data([1, 2, 3]),
    clientID: "cli-idempotent"
  )

  #expect(message.attachmentID == oldAttachmentID)
  #expect(await recorder.requests().contains(where: isNewAttachmentDelete))
}

@Test func networkChatRepositoryAbortsAttachmentWhenImageUploadIsCancelled() async throws {
  let recorder = ImageChatRequestRecorder()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await recorder.record(request)
    if request.url?.path() == "/uploads/initiate" {
      return imagePipelineResponse(
        request: request,
        returnedAttachmentID: ChatWireFixture.attachmentID
      )
    }
    return APIResponse(data: Data(), statusCode: 204)
  }
  let uploader = OSSPartUploader { _, _ in
    throw CancellationError()
  }
  let repository = imageRepository(client: client, uploader: uploader)

  await #expect(throws: CancellationError.self) {
    try await repository.sendImage(
      in: ChatWireFixture.conversationID,
      imageData: Data([1, 2, 3]),
      clientID: "cli-cancelled"
    )
  }

  let requests = await recorder.requests()
  #expect(
    requests.map { "\($0.httpMethod ?? "?") \($0.url?.path() ?? "?")" } == [
      "POST /uploads/initiate",
      "POST /uploads/\(ChatWireFixture.attachmentID.uuidString)/abort",
    ]
  )
}

@Test func networkChatRepositoryDeletesCompletedAttachmentWhenMessageFails() async throws {
  let recorder = ImageChatRequestRecorder()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await recorder.record(request)
    if request.url?.path().hasSuffix("/messages") == true {
      return APIResponse(
        data: Data(#"{"error":"CHAT_BIND_REQUIRED"}"#.utf8),
        statusCode: 403
      )
    }
    return imagePipelineResponse(
      request: request,
      returnedAttachmentID: ChatWireFixture.attachmentID
    )
  }
  let repository = imageRepository(client: client)

  await #expect(throws: ChatRepositoryError.bindRequired) {
    try await repository.sendImage(
      in: ChatWireFixture.conversationID,
      imageData: Data([1, 2, 3]),
      clientID: "cli-failed"
    )
  }

  #expect(await recorder.requests().contains(where: isNewAttachmentDelete))
}

private func assertImagePipelineRequests(
  _ requests: [URLRequest],
  jpegCount: Int
) throws {
  try #require(requests.count == 3)
  #expect(
    requests.map { "\($0.httpMethod ?? "?") \($0.url?.path() ?? "?")" } == [
      "POST /uploads/initiate",
      "POST /uploads/\(ChatWireFixture.attachmentID.uuidString)/complete",
      "POST /conversations/\(ChatWireFixture.conversationID.uuidString)/messages",
    ]
  )
  let initiateBody = try imageJSONBody(requests[0])
  #expect(initiateBody["kind"] as? String == "chat_image")
  #expect(initiateBody["content_type"] as? String == "image/jpeg")
  #expect(initiateBody["size_bytes"] as? Int == jpegCount)
  #expect(initiateBody["part_count"] as? Int == 1)
  #expect(initiateBody["set_log_id"] == nil)
  let completeBody = try imageJSONBody(requests[1])
  let parts = try #require(completeBody["parts"] as? [[String: Any]])
  let part = try #require(parts.first)
  #expect(part["etag"] as? String == "etag-chat")
  #expect(part["part_number"] as? Int == 1)
  let messageBody = try imageJSONBody(requests[2])
  #expect(messageBody.count == 3)
  #expect(messageBody["kind"] as? String == "image")
  #expect(messageBody["attachment_id"] as? String == ChatWireFixture.attachmentID.uuidString)
  #expect(messageBody["client_id"] as? String == "cli-image")
}

private func imageRepository(
  client: APIClient,
  uploader: OSSPartUploader? = nil
) -> NetworkChatRepository {
  NetworkChatRepository(
    apiClient: client,
    session: ImageChatSessionStub(),
    uploader: uploader
      ?? OSSPartUploader { _, _ in
        OSSPartUploadResponse(statusCode: 200, headers: ["ETag": "etag-chat"])
      }
  )
}

private struct ImageChatSessionStub: SessionStateReader {
  func accessToken() async throws -> String { "chat-token" }

  func currentUser() async throws -> User {
    throw SessionStateReaderError.missingCurrentUser
  }
}

private actor ImageChatRequestRecorder {
  private var capturedRequests: [URLRequest] = []

  func record(_ request: URLRequest) { capturedRequests.append(request) }

  func requests() -> [URLRequest] { capturedRequests }
}

private actor ChatPartUploadRecorder {
  struct Upload: Sendable {
    let request: URLRequest
    let data: Data
  }

  private(set) var upload: Upload?

  func record(request: URLRequest, data: Data) {
    upload = Upload(request: request, data: data)
  }
}

private func imageJSONBody(_ request: URLRequest) throws -> [String: Any] {
  let data = try #require(request.httpBody)
  return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func isNewAttachmentDelete(_ request: URLRequest) -> Bool {
  request.httpMethod == "DELETE"
    && request.url?.path() == "/uploads/\(ChatWireFixture.attachmentID.uuidString)"
}

private func imagePipelineResponse(
  request: URLRequest,
  returnedAttachmentID: UUID
) -> APIResponse {
  let path = request.url?.path() ?? ""
  if path == "/uploads/initiate" {
    return APIResponse(data: initiateImageResponse(), statusCode: 201)
  }
  if path.hasSuffix("/complete") {
    return APIResponse(data: chatAttachmentResponse(), statusCode: 200)
  }
  if path.hasSuffix("/messages") {
    return APIResponse(
      data: imageMessageResponse(
        attachmentID: returnedAttachmentID,
        clientID: imageRequestClientID(request)
      ),
      statusCode: returnedAttachmentID == ChatWireFixture.attachmentID ? 201 : 200
    )
  }
  if request.httpMethod == "DELETE" {
    return APIResponse(data: Data(), statusCode: 204)
  }
  return APIResponse(data: Data(), statusCode: 404)
}

private func initiateImageResponse() -> Data {
  Data(
    """
    {
      "attachment_id": "\(ChatWireFixture.attachmentID.uuidString)",
      "upload_id": "upload-chat",
      "part_urls": [{
        "part_number": 1,
        "url": "https://oss.example.test/chat?partNumber=1"
      }]
    }
    """.utf8
  )
}

private func chatAttachmentResponse() -> Data {
  Data(
    """
    {
      "id": "\(ChatWireFixture.attachmentID.uuidString)",
      "owner_id": "\(ChatWireFixture.otherUserID.uuidString)",
      "kind": "chat_image",
      "oss_key": "attachments/chat/image.jpg",
      "content_type": "image/jpeg",
      "size_bytes": 4,
      "filename": "chat-cli-image.jpg",
      "status": "ready",
      "created_at": "2026-07-20T09:10:00.000Z",
      "updated_at": "2026-07-20T09:10:01.000Z"
    }
    """.utf8
  )
}

private func imageMessageResponse(attachmentID: UUID, clientID: String) -> Data {
  Data(
    """
    {
      "message": {
        "id": "\(ChatWireFixture.imageMessageID.uuidString)",
        "conversation_id": "\(ChatWireFixture.conversationID.uuidString)",
        "seq": 41,
        "sender_id": "\(ChatWireFixture.otherUserID.uuidString)",
        "kind": "image",
        "body": null,
        "attachment_id": "\(attachmentID.uuidString)",
        "image_url": null,
        "image_expires_in": null,
        "client_id": "\(clientID)",
        "created_at": "2026-07-20T09:10:00.000Z"
      }
    }
    """.utf8
  )
}

private func imageRequestClientID(_ request: URLRequest) -> String {
  guard let data = request.httpBody,
    let body = try? MeetPRCodec.decoder.decode(ChatSendMessageRequestDTO.self, from: data)
  else {
    return ""
  }
  return body.clientID
}

private func imageTestUUID(_ suffix: UInt8) -> UUID {
  UUID(uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0x5B, suffix))
}
