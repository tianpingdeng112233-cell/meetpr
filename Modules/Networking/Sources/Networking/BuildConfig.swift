import Foundation

public enum BuildConfig {
  /// Release defaults to the public TLS endpoint. Deploy-time DNS/certificate
  /// provisioning must point this hostname at the API load balancer.
  public static let productionBackendBaseURL = "https://api.meetpr.app"

  public static var backendBaseURL: URL {
    backendBaseURL(environment: ProcessInfo.processInfo.environment)
  }

  public static func backendBaseURL(environment: [String: String]) -> URL {
    if let url = configuredBaseURL(environment: environment) {
      return validatedHTTPSURL(url)
    }

    guard let url = URL(string: productionBackendBaseURL) else {
      preconditionFailure("Production backend base URL is invalid.")
    }
    return validatedHTTPSURL(url)
  }

  static func configuredBaseURL(environment: [String: String]) -> URL? {
    if let baseURLString = environment["MEETPR_API_BASE_URL"],
      let url = URL(string: baseURLString)
    {
      return url
    }

    guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: "BackendBaseURL") as? String,
      !baseURLString.isEmpty,
      !baseURLString.hasPrefix("$(")
    else {
      return nil
    }
    return URL(string: baseURLString)
  }

  private static func validatedHTTPSURL(_ url: URL) -> URL {
    guard
      url.scheme?.lowercased() == "https",
      url.host?.isEmpty == false
    else {
      preconditionFailure("MeetPR backend must use a valid HTTPS URL.")
    }
    return url
  }
}
