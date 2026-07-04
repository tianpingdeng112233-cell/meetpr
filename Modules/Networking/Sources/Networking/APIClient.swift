import CoreModels
import Foundation

public struct APIResponse: Sendable, Equatable {
  public let data: Data
  public let statusCode: Int

  public init(data: Data, statusCode: Int) {
    self.data = data
    self.statusCode = statusCode
  }
}

public enum APIError: Error, Equatable, Sendable {
  case invalidResponse
  case authInvalid
  case httpStatus(Int, Data)
}

public enum APIClientError: Error, Equatable, Sendable {
  case invalidResponse
  case httpStatus(Int, Data)
}

public final class APIClient: Sendable {
  public typealias Transport = @Sendable (URLRequest) async throws -> APIResponse

  public static let shared = APIClient()

  public let baseURL: URL
  public let errorStream: AsyncStream<APIError>

  private let transport: Transport
  private let errorContinuation: AsyncStream<APIError>.Continuation

  public init(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    transport: Transport? = nil
  ) {
    baseURL = BuildConfig.backendBaseURL(environment: environment)

    self.transport =
      transport ?? { request in
        try await Self.liveTransport(request: request)
      }

    let stream = AsyncStream.makeStream(
      of: APIError.self,
      bufferingPolicy: .bufferingNewest(20)
    )
    errorStream = stream.stream
    errorContinuation = stream.continuation
  }

  public func get(_ endpoint: Endpoint) async throws -> Data {
    var request = URLRequest(url: url(for: endpoint))
    request.httpMethod = "GET"
    return try await perform(request, emitsAuthInvalidOn401: false)
  }

  public func post(_ endpoint: Endpoint, body: Data) async throws -> Data {
    var request = URLRequest(url: url(for: endpoint))
    request.httpMethod = "POST"
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    request.setValue("application/json", forHTTPHeaderField: "accept")
    return try await perform(request, emitsAuthInvalidOn401: false)
  }

  public func get<Response: Decodable>(
    path: String,
    queryItems: [URLQueryItem] = [],
    accessToken: String,
    as responseType: Response.Type = Response.self
  ) async throws -> Response {
    var request = URLRequest(url: url(path: path, queryItems: queryItems))
    request.httpMethod = "GET"
    authorize(&request, accessToken: accessToken)
    request.setValue("application/json", forHTTPHeaderField: "accept")

    let data = try await perform(request, emitsAuthInvalidOn401: true)
    return try MeetPRCodec.decoder.decode(responseType, from: data)
  }

  public func post<Request: Encodable, Response: Decodable>(
    path: String,
    body: Request,
    accessToken: String,
    as responseType: Response.Type = Response.self
  ) async throws -> Response {
    var request = URLRequest(url: url(path: path))
    request.httpMethod = "POST"
    authorize(&request, accessToken: accessToken)
    request.httpBody = try MeetPRCodec.encoder.encode(body)
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    request.setValue("application/json", forHTTPHeaderField: "accept")

    let data = try await perform(request, emitsAuthInvalidOn401: true)
    return try MeetPRCodec.decoder.decode(responseType, from: data)
  }

  public func post<Response: Decodable>(
    path: String,
    accessToken: String,
    as responseType: Response.Type = Response.self
  ) async throws -> Response {
    var request = URLRequest(url: url(path: path))
    request.httpMethod = "POST"
    authorize(&request, accessToken: accessToken)
    request.setValue("application/json", forHTTPHeaderField: "accept")

    let data = try await perform(request, emitsAuthInvalidOn401: true)
    return try MeetPRCodec.decoder.decode(responseType, from: data)
  }

  public func postNoContent<Request: Encodable>(
    path: String,
    body: Request,
    accessToken: String
  ) async throws {
    var request = URLRequest(url: url(path: path))
    request.httpMethod = "POST"
    authorize(&request, accessToken: accessToken)
    request.httpBody = try MeetPRCodec.encoder.encode(body)
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    request.setValue("application/json", forHTTPHeaderField: "accept")

    _ = try await perform(request, emitsAuthInvalidOn401: true)
  }

  public func patchNoContent(path: String, accessToken: String) async throws {
    var request = URLRequest(url: url(path: path))
    request.httpMethod = "PATCH"
    authorize(&request, accessToken: accessToken)

    _ = try await perform(request, emitsAuthInvalidOn401: true)
  }

  public func put<Request: Encodable, Response: Decodable>(
    path: String,
    body: Request,
    accessToken: String,
    as responseType: Response.Type = Response.self
  ) async throws -> Response {
    var request = URLRequest(url: url(path: path))
    request.httpMethod = "PUT"
    authorize(&request, accessToken: accessToken)
    request.httpBody = try MeetPRCodec.encoder.encode(body)
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    request.setValue("application/json", forHTTPHeaderField: "accept")

    let data = try await perform(request, emitsAuthInvalidOn401: true)
    return try MeetPRCodec.decoder.decode(responseType, from: data)
  }

  public func putNoContent<Request: Encodable>(
    path: String,
    body: Request,
    accessToken: String
  ) async throws {
    var request = URLRequest(url: url(path: path))
    request.httpMethod = "PUT"
    authorize(&request, accessToken: accessToken)
    request.httpBody = try MeetPRCodec.encoder.encode(body)
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    request.setValue("application/json", forHTTPHeaderField: "accept")

    _ = try await perform(request, emitsAuthInvalidOn401: true)
  }

  public func deleteNoContent(path: String, accessToken: String) async throws {
    var request = URLRequest(url: url(path: path))
    request.httpMethod = "DELETE"
    authorize(&request, accessToken: accessToken)

    _ = try await perform(request, emitsAuthInvalidOn401: true)
  }

  private func url(for endpoint: Endpoint) -> URL {
    let path = endpoint.path.hasPrefix("/") ? String(endpoint.path.dropFirst()) : endpoint.path
    return baseURL.appending(path: path)
  }

  private func url(path: String, queryItems: [URLQueryItem] = []) -> URL {
    var url = baseURL
    let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
    for component in normalizedPath.split(separator: "/") {
      url.append(path: String(component))
    }

    guard !queryItems.isEmpty else {
      return url
    }

    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      preconditionFailure("API URL components are invalid for path \(path).")
    }
    components.queryItems = queryItems

    guard let resolvedURL = components.url else {
      preconditionFailure("API URL query items are invalid for path \(path).")
    }
    return resolvedURL
  }

  private func authorize(_ request: inout URLRequest, accessToken: String) {
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
  }

  private func perform(_ request: URLRequest, emitsAuthInvalidOn401: Bool) async throws -> Data {
    let response = try await transport(request)
    guard !(emitsAuthInvalidOn401 && response.statusCode == 401) else {
      errorContinuation.yield(.authInvalid)
      throw APIError.authInvalid
    }

    guard (200..<300).contains(response.statusCode) else {
      throw APIError.httpStatus(response.statusCode, response.data)
    }
    return response.data
  }

  private static func liveTransport(request: URLRequest) async throws -> APIResponse {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw APIError.invalidResponse
    }
    return APIResponse(data: data, statusCode: httpResponse.statusCode)
  }

}
