import Foundation

public final class APIClient: Sendable {
  public static let shared = APIClient()

  public let baseURL: URL

  public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
    if let configuredBaseURL = Self.configuredBaseURL(from: environment) {
      baseURL = configuredBaseURL
    } else {
      baseURL = Self.defaultBaseURL()
    }
  }

  public func get(_ endpoint: Endpoint) async throws -> Data {
    Data(endpoint.path.utf8)
  }

  public func post(_ endpoint: Endpoint, body: Data) async throws -> Data {
    Data(endpoint.path.utf8) + body
  }

  private static func configuredBaseURL(from environment: [String: String]) -> URL? {
    guard let baseURLString = environment["MEETPR_API_BASE_URL"] else {
      return nil
    }
    return URL(string: baseURLString)
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
