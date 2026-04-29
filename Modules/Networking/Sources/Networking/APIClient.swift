import Foundation

public struct APIResponse: Sendable, Equatable {
  public let data: Data
  public let statusCode: Int

  public init(data: Data, statusCode: Int) {
    self.data = data
    self.statusCode = statusCode
  }
}

public enum APIClientError: Error, Equatable, Sendable {
  case invalidResponse
  case httpStatus(Int, Data)
}

public final class APIClient: Sendable {
  public typealias Transport = @Sendable (URLRequest) async throws -> APIResponse

  public static let shared = APIClient()

  public let baseURL: URL
  private let transport: Transport

  public init(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    transport: Transport? = nil
  ) {
    if let configuredBaseURL = Self.configuredBaseURL(from: environment) {
      baseURL = configuredBaseURL
    } else {
      baseURL = Self.defaultBaseURL()
    }

    self.transport =
      transport ?? { request in
        try await Self.liveTransport(request: request)
      }
  }

  public func get(_ endpoint: Endpoint) async throws -> Data {
    var request = URLRequest(url: url(for: endpoint))
    request.httpMethod = "GET"
    return try await perform(request)
  }

  public func post(_ endpoint: Endpoint, body: Data) async throws -> Data {
    var request = URLRequest(url: url(for: endpoint))
    request.httpMethod = "POST"
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    request.setValue("application/json", forHTTPHeaderField: "accept")
    return try await perform(request)
  }

  private static func configuredBaseURL(from environment: [String: String]) -> URL? {
    guard let baseURLString = environment["MEETPR_API_BASE_URL"] else {
      return nil
    }
    return URL(string: baseURLString)
  }

  private func url(for endpoint: Endpoint) -> URL {
    let path = endpoint.path.hasPrefix("/") ? String(endpoint.path.dropFirst()) : endpoint.path
    return baseURL.appending(path: path)
  }

  private func perform(_ request: URLRequest) async throws -> Data {
    let response = try await transport(request)
    guard (200..<300).contains(response.statusCode) else {
      throw APIClientError.httpStatus(response.statusCode, response.data)
    }
    return response.data
  }

  private static func liveTransport(request: URLRequest) async throws -> APIResponse {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw APIClientError.invalidResponse
    }
    return APIResponse(data: data, statusCode: httpResponse.statusCode)
  }

  private static func defaultBaseURL() -> URL {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "api.meetpr.local"
    guard let url = components.url else {
      preconditionFailure("Default API base URL components are invalid.")
    }
    return url
  }
}
