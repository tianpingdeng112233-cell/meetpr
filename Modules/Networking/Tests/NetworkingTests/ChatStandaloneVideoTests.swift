import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func standaloneVideoDecodesWithoutChangingLegacyMessageKind() throws {
  let data = Data(
    #"""
    {"id":"00000000-0000-0000-0000-000000000001",
    "conversation_id":"00000000-0000-0000-0000-000000000002",
    "seq":1,
    "sender_id":"00000000-0000-0000-0000-000000000003",
    "kind":"text",
    "body":"[视频]",
    "video_id":"00000000-0000-0000-0000-000000000004",
    "video_url":null,
    "set_ref":null,
    "client_id":"ios-video",
    "created_at":"2026-11-17T12:00:00Z"}
    """#
    .utf8)
  let message = try MeetPRCodec.decoder.decode(ChatMessageDTO.self, from: data).toDomain()
  #expect(message.kind == .text)
  #expect(message.isStandaloneVideo)
  #expect(message.videoID == UUID(uuidString: "00000000-0000-0000-0000-000000000004"))
  #expect(message.videoURL == nil)
}

@Test func standaloneVideoUploadsInBoundedPartsThenSendsCompatibleMessage() async throws {
  let recorder = StandaloneVideoTransport()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    try await recorder.respond(request)
  }
  let uploader = OSSPartUploader { _, data in
    await recorder.recordPart(data.count)
    return OSSPartUploadResponse(statusCode: 200, headers: ["ETag": "video-etag"])
  }
  let repository = NetworkChatRepository(
    apiClient: client, session: VideoSession(), uploader: uploader)
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(
    UUID().uuidString + ".mp4")
  let bytes = 6 * 1024 * 1024
  try Data(repeating: 3, count: bytes).write(to: url)
  defer { try? FileManager.default.removeItem(at: url) }
  let message = try await repository.sendVideo(
    in: StandaloneVideoTransport.conversationID,
    video: ChatVideoFile(fileURL: url, contentType: "video/mp4", byteCount: Int64(bytes)),
    clientID: "video-client", progress: { value in await recorder.recordProgress(value) })
  #expect(message.isStandaloneVideo)
  #expect(await recorder.parts == [5 * 1024 * 1024, 1024 * 1024])
  #expect(await recorder.progress == [0, 5.0 / 6.0, 1])
  let requests = await recorder.requests
  #expect(
    requests.map { $0.url?.path() ?? "" } == [
      "/uploads/initiate", "/uploads/\(StandaloneVideoTransport.attachmentID)/complete",
      "/conversations/\(StandaloneVideoTransport.conversationID.uuidString)/messages",
    ])
  let first = try #require(requests.first?.httpBody)
  let initiate = try #require(try JSONSerialization.jsonObject(with: first) as? [String: Any])
  #expect(initiate["kind"] as? String == "chat_video")
  #expect(initiate["part_count"] as? Int == 2)
  #expect(initiate["set_log_id"] == nil)
  let last = try #require(requests.last?.httpBody)
  let sent = try #require(try JSONSerialization.jsonObject(with: last) as? [String: Any])
  #expect(sent["kind"] as? String == "text")
  #expect(sent["body"] as? String == "[视频]")
  #expect(sent["video_id"] as? String == StandaloneVideoTransport.attachmentID)
  #expect(sent["client_id"] as? String == "video-client")
  #expect(sent["set_ref"] == nil)
}

private struct VideoSession: SessionStateReader {
  func accessToken() async throws -> String { "fixture-token" }
  func currentUser() async throws -> User { throw SessionStateReaderError.missingCurrentUser }
}

private actor StandaloneVideoTransport {
  let failure: String?
  init(failure: String? = nil) { self.failure = failure }
  static let conversationID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
  static let attachmentID = "00000000-0000-0000-0000-000000000004"
  var requests: [URLRequest] = []
  var parts: [Int] = []
  var progress: [Double] = []
  func recordPart(_ count: Int) { parts.append(count) }
  func recordProgress(_ value: Double) { progress.append(value) }
  func respond(_ request: URLRequest) throws -> APIResponse {
    requests.append(request)
    if request.httpMethod == "DELETE" || request.url?.path().hasSuffix("/abort") == true {
      return APIResponse(data: Data(), statusCode: 204)
    }
    if (failure == "complete" && request.url?.path().hasSuffix("/complete") == true)
      || (failure == "send" && request.url?.path().hasSuffix("/messages") == true)
    {
      return APIResponse(data: Data(), statusCode: 500)
    }
    let body: String
    switch request.url?.path() {
    case "/uploads/initiate":
      body =
        #"""
        {"attachment_id":"00000000-0000-0000-0000-000000000004",
        "upload_id":"fixture",
        "part_urls":[{"part_number":1,
        "url":"https://oss.test/1"},{"part_number":2,
        "url":"https://oss.test/2"}]}
        """#
    case let path where path?.hasSuffix("/complete") == true:
      body =
        #"""
        {"id":"00000000-0000-0000-0000-000000000004",
        "owner_id":"00000000-0000-0000-0000-000000000003",
        "kind":"chat_video",
        "oss_key":"video.mp4",
        "content_type":"video/mp4",
        "size_bytes":6291456,
        "status":"ready",
        "created_at":"2026-11-17T12:00:00Z",
        "updated_at":"2026-11-17T12:00:00Z"}
        """#
    default:
      body =
        #"""
        {"message":{"id":"00000000-0000-0000-0000-000000000001",
        "conversation_id":"00000000-0000-0000-0000-000000000002",
        "seq":1,
        "sender_id":"00000000-0000-0000-0000-000000000003",
        "kind":"text",
        "body":"[视频]",
        "video_id":"00000000-0000-0000-0000-000000000004",
        "client_id":"video-client",
        "created_at":"2026-11-17T12:00:00Z"}}
        """#
    }
    return APIResponse(data: Data(body.utf8), statusCode: 200)
  }
}

@Test(arguments: ["part", "complete", "send"])
func standaloneVideoFailureCleansRemoteUpload(failure: String) async throws {
  let recorder = StandaloneVideoTransport(failure: failure)
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    try await recorder.respond(request)
  }
  let uploader = OSSPartUploader { _, _ in
    if failure == "part" { throw URLError(.networkConnectionLost) }
    return OSSPartUploadResponse(statusCode: 200, headers: ["ETag": "video-etag"])
  }
  let repository = NetworkChatRepository(
    apiClient: client, session: VideoSession(), uploader: uploader)
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(
    UUID().uuidString + ".mp4")
  let bytes = 6 * 1024 * 1024
  try Data(repeating: 3, count: bytes).write(to: url)
  defer { try? FileManager.default.removeItem(at: url) }
  await #expect(throws: (any Error).self) {
    try await repository.sendVideo(
      in: StandaloneVideoTransport.conversationID,
      video: ChatVideoFile(fileURL: url, contentType: "video/mp4", byteCount: Int64(bytes)),
      clientID: "cleanup-video", progress: { _ in })
  }
  let requests = await recorder.requests
  let last = try #require(requests.last)
  if failure == "send" {
    #expect(last.httpMethod == "DELETE")
    #expect(last.url?.path() == "/uploads/\(StandaloneVideoTransport.attachmentID)")
  } else {
    #expect(last.url?.path() == "/uploads/\(StandaloneVideoTransport.attachmentID)/abort")
    #expect(!requests.contains { $0.url?.path().hasSuffix("/messages") == true })
  }
  #expect(FileManager.default.fileExists(atPath: url.path))
}
