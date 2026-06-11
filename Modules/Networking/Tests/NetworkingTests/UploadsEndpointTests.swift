import CoreModels
import Foundation
import Testing

@testable import Networking

private let attachmentID = UUID(uuidString: "00000000-0000-4000-8000-000000000601")!
private let ownerID = UUID(uuidString: "00000000-0000-4000-8000-000000000602")!

@Test func uploadEndpointsUseBackendWirePaths() async throws {
  let log = UploadRequestLog()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await log.record(request)
    return UploadResponseStub.response(for: request)
  }

  let initiated = try await client.initiateUpload(
    InitiateUploadRequestDTO(
      kind: .setVideo,
      contentType: "video/mp4",
      sizeBytes: 15_728_640,
      partCount: 3,
      filename: "setlog-test.mp4"
    ),
    accessToken: "token"
  )
  #expect(initiated.attachmentID == attachmentID)
  #expect(initiated.uploadID == "oss-upload-1")
  #expect(initiated.partURLs.count == 3)
  #expect(initiated.partURLs[0].partNumber == 1)
  #expect(initiated.partURLs[0].url == "https://bucket.oss.test/key?partNumber=1")

  let completed = try await client.completeUpload(
    attachmentID: attachmentID,
    parts: [
      UploadPartETagDTO(partNumber: 1, etag: "AAA"),
      UploadPartETagDTO(partNumber: 2, etag: "BBB"),
    ],
    accessToken: "token"
  )
  #expect(completed.id == attachmentID)
  #expect(completed.status == .ready)
  #expect(completed.kind == .setVideo)
  #expect(completed.filename == nil)

  try await client.abortUpload(attachmentID: attachmentID, accessToken: "token")

  let playback = try await client.attachmentURL(attachmentID: attachmentID, accessToken: "token")
  #expect(playback.url == "https://bucket.oss.test/key?signature=abc")
  #expect(playback.expiresIn == 900)

  let requests = await log.requests()
  #expect(
    requests.map(\.methodAndPath) == [
      "POST /uploads/initiate",
      "POST /uploads/\(attachmentID.uuidString)/complete",
      "POST /uploads/\(attachmentID.uuidString)/abort",
      "GET /uploads/\(attachmentID.uuidString)/url",
    ]
  )
}

@Test func initiateUploadEncodesSnakeCaseWireBody() async throws {
  let log = UploadRequestLog()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await log.record(request)
    return UploadResponseStub.response(for: request)
  }

  _ = try await client.initiateUpload(
    InitiateUploadRequestDTO(
      kind: .setVideo,
      contentType: "video/mp4",
      sizeBytes: 100,
      partCount: 1,
      filename: "setlog-abc.mp4"
    ),
    accessToken: "token"
  )

  let body = try #require(await log.requests().first?.httpBody)
  let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
  #expect(json["kind"] as? String == "set_video")
  #expect(json["content_type"] as? String == "video/mp4")
  #expect(json["size_bytes"] as? Int == 100)
  #expect(json["part_count"] as? Int == 1)
  #expect(json["filename"] as? String == "setlog-abc.mp4")
  #expect(json.count == 5)
}

@Test func initiateUploadOmitsNilFilename() async throws {
  let log = UploadRequestLog()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await log.record(request)
    return UploadResponseStub.response(for: request)
  }

  _ = try await client.initiateUpload(
    InitiateUploadRequestDTO(kind: .setVideo, contentType: "video/mp4", sizeBytes: 1, partCount: 1),
    accessToken: "token"
  )

  let body = try #require(await log.requests().first?.httpBody)
  let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
  // zod `.strict()` rejects null for `.optional()` fields — the key must be
  // absent, not null.
  #expect(json["filename"] == nil)
  #expect(json.count == 4)
}

@Test func abortUploadSendsStrictlyEmptyObjectBody() async throws {
  let log = UploadRequestLog()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await log.record(request)
    return UploadResponseStub.response(for: request)
  }

  try await client.abortUpload(attachmentID: attachmentID, accessToken: "token")

  let body = try #require(await log.requests().first?.httpBody)
  #expect(String(data: body, encoding: .utf8) == "{}")
}

@Test func completeUploadEncodesPartsAsSnakeCase() async throws {
  let log = UploadRequestLog()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await log.record(request)
    return UploadResponseStub.response(for: request)
  }

  _ = try await client.completeUpload(
    attachmentID: attachmentID,
    parts: [UploadPartETagDTO(partNumber: 7, etag: "ETAG7")],
    accessToken: "token"
  )

  let body = try #require(await log.requests().first?.httpBody)
  let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
  let parts = try #require(json["parts"] as? [[String: Any]])
  #expect(parts.count == 1)
  #expect(parts[0]["part_number"] as? Int == 7)
  #expect(parts[0]["etag"] as? String == "ETAG7")
}

// MARK: - Stubs

private actor UploadRequestLog {
  private var capturedRequests: [URLRequest] = []

  func record(_ request: URLRequest) {
    capturedRequests.append(request)
  }

  func requests() -> [URLRequest] {
    capturedRequests
  }
}

extension URLRequest {
  fileprivate var methodAndPath: String {
    let method = httpMethod ?? "?"
    let path = url?.path() ?? "?"
    let query = url?.query().map { "?\($0)" } ?? ""
    return "\(method) \(path)\(query)"
  }
}

private enum UploadResponseStub {
  static func response(for request: URLRequest) -> APIResponse {
    let path = request.url?.path() ?? ""
    if path.hasSuffix("/uploads/initiate") {
      return APIResponse(data: initiateBody, statusCode: 201)
    }
    if path.hasSuffix("/complete") {
      return APIResponse(data: attachmentBody, statusCode: 200)
    }
    if path.hasSuffix("/abort") {
      return APIResponse(data: Data(), statusCode: 204)
    }
    if path.hasSuffix("/url") {
      return APIResponse(data: urlBody, statusCode: 200)
    }
    return APIResponse(data: Data(), statusCode: 404)
  }

  private static var initiateBody: Data {
    Data(
      """
      {
        "attachment_id": "\(attachmentID.uuidString.lowercased())",
        "upload_id": "oss-upload-1",
        "part_urls": [
          {"part_number": 1, "url": "https://bucket.oss.test/key?partNumber=1"},
          {"part_number": 2, "url": "https://bucket.oss.test/key?partNumber=2"},
          {"part_number": 3, "url": "https://bucket.oss.test/key?partNumber=3"}
        ]
      }
      """.utf8)
  }

  private static var attachmentBody: Data {
    Data(
      """
      {
        "id": "\(attachmentID.uuidString.lowercased())",
        "owner_id": "\(ownerID.uuidString.lowercased())",
        "kind": "set_video",
        "oss_key": "attachments/\(ownerID.uuidString.lowercased())/file.mp4",
        "content_type": "video/mp4",
        "size_bytes": 15728640,
        "filename": null,
        "status": "ready",
        "created_at": "2026-06-11T10:00:00.000Z",
        "updated_at": "2026-06-11T10:02:30.000Z"
      }
      """.utf8)
  }

  private static var urlBody: Data {
    Data(
      """
      {"url": "https://bucket.oss.test/key?signature=abc", "expires_in": 900}
      """.utf8)
  }
}
