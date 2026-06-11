import Foundation
import Testing

@testable import Networking

@Test func partUploaderSendsPUTAndStripsETagQuotes() async throws {
  let recorder = PartUploadRecorder()
  let uploader = OSSPartUploader { request, body in
    await recorder.record(request: request, body: body)
    return OSSPartUploadResponse(statusCode: 200, headers: ["ETag": "\"5D41402ABC4B2A76\""])
  }
  let url = try #require(URL(string: "https://bucket.oss-cn-hangzhou.test/key?partNumber=1"))
  let payload = Data(repeating: 1, count: 16)

  let etag = try await uploader.uploadPart(to: url, data: payload)

  #expect(etag == "5D41402ABC4B2A76")
  let recorded = try #require(await recorder.last)
  #expect(recorded.request.httpMethod == "PUT")
  #expect(recorded.request.url == url)
  #expect(recorded.body == payload)
  #expect(recorded.request.timeoutInterval == OSSPartUploader.partTimeoutSeconds)
}

@Test func partUploaderReadsCaseInsensitiveETagHeader() async throws {
  let uploader = OSSPartUploader { _, _ in
    OSSPartUploadResponse(statusCode: 200, headers: ["etag": "\"abc\""])
  }
  let url = try #require(URL(string: "https://oss.test/key"))

  let etag = try await uploader.uploadPart(to: url, data: Data([1]))
  #expect(etag == "abc")
}

@Test func partUploaderThrowsOnMissingETag() async throws {
  let uploader = OSSPartUploader { _, _ in
    OSSPartUploadResponse(statusCode: 200, headers: [:])
  }
  let url = try #require(URL(string: "https://oss.test/key"))

  await #expect(throws: OSSPartUploadError.missingETag) {
    try await uploader.uploadPart(to: url, data: Data([1]))
  }
}

@Test func partUploaderThrowsOnHTTPFailure() async throws {
  let uploader = OSSPartUploader { _, _ in
    OSSPartUploadResponse(statusCode: 403, headers: ["ETag": "\"ignored\""])
  }
  let url = try #require(URL(string: "https://oss.test/key"))

  await #expect(throws: OSSPartUploadError.httpStatus(403)) {
    try await uploader.uploadPart(to: url, data: Data([1]))
  }
}

private actor PartUploadRecorder {
  struct Recorded {
    let request: URLRequest
    let body: Data
  }

  private(set) var last: Recorded?

  func record(request: URLRequest, body: Data) {
    last = Recorded(request: request, body: body)
  }
}
