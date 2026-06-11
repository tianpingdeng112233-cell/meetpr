import Foundation

public enum OSSPartUploadError: Error, Equatable, Sendable {
  case invalidResponse
  case httpStatus(Int)
  case missingETag
}

public struct OSSPartUploadResponse: Sendable, Equatable {
  public let statusCode: Int
  public let headers: [String: String]

  public init(statusCode: Int, headers: [String: String]) {
    self.statusCode = statusCode
    self.headers = headers
  }
}

/// PUTs one multipart chunk to a presigned OSS URL.
///
/// Presigned part URLs live on the OSS domain, not the backend base URL, so
/// this deliberately bypasses `APIClient` and talks to `URLSession` directly.
/// OSS answers each part PUT with an `ETag` header that the backend needs at
/// complete time; the value arrives wrapped in double quotes which OSS does
/// not accept back, so they are stripped here.
public struct OSSPartUploader: Sendable {
  public typealias Transport = @Sendable (URLRequest, Data) async throws -> OSSPartUploadResponse

  /// Per-part PUT timeout (spec 027 §chunk size + retry).
  public static let partTimeoutSeconds: TimeInterval = 60

  private let transport: Transport

  public init(transport: Transport? = nil) {
    self.transport = transport ?? Self.liveTransport
  }

  /// Uploads one part and returns its unquoted ETag.
  public func uploadPart(to url: URL, data: Data) async throws -> String {
    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    request.timeoutInterval = Self.partTimeoutSeconds
    // Deliberately NO Content-Type header: backend presigned part URLs are
    // signed without one, and OSS folds Content-Type into the signature —
    // sending it would 403 the real upload (Codex review P1).

    let response = try await transport(request, data)
    guard (200..<300).contains(response.statusCode) else {
      throw OSSPartUploadError.httpStatus(response.statusCode)
    }

    let etagHeader = response.headers.first {
      $0.key.caseInsensitiveCompare("etag") == .orderedSame
    }
    guard let rawETag = etagHeader?.value else {
      throw OSSPartUploadError.missingETag
    }

    let trimmed = rawETag.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    guard !trimmed.isEmpty else {
      throw OSSPartUploadError.missingETag
    }
    return trimmed
  }

  @Sendable
  private static func liveTransport(
    request: URLRequest,
    body: Data
  ) async throws -> OSSPartUploadResponse {
    let (_, response) = try await URLSession.shared.upload(for: request, from: body)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw OSSPartUploadError.invalidResponse
    }

    var headers: [String: String] = [:]
    for (key, value) in httpResponse.allHeaderFields {
      guard let name = key as? String, let stringValue = value as? String else { continue }
      headers[name] = stringValue
    }
    return OSSPartUploadResponse(statusCode: httpResponse.statusCode, headers: headers)
  }
}
