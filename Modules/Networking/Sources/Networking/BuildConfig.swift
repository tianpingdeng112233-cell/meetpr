import Foundation

public enum BuildConfig {
  public static let productionBackendBaseURL = "http://120.27.243.110:3000"

  public static var backendBaseURL: URL {
    backendBaseURL(environment: ProcessInfo.processInfo.environment)
  }

  public static func backendBaseURL(environment: [String: String]) -> URL {
    if let url = configuredBaseURL(environment: environment) {
      return url
    }

    guard let url = URL(string: productionBackendBaseURL) else {
      preconditionFailure("Production backend base URL is invalid.")
    }
    return url
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
}
