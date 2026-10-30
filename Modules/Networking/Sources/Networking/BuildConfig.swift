import Foundation

public enum MeetPRBuildTrack: Sendable, Equatable {
  case china
  case global
}

public enum BuildConfig {
  public static func buildNumber(infoDictionary: [String: Any]? = Bundle.main.infoDictionary)
    -> Int?
  {
    guard let raw = infoDictionary?["CFBundleVersion"] as? String,
      let build = Int(raw), build >= 0
    else { return nil }
    return build
  }

  public static func updateURL(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) -> URL?
  {
    guard let raw = infoDictionary?["MeetPRUpdateURL"] as? String,
      let url = URL(string: raw), url.scheme == "https", url.host != nil
    else { return nil }
    return url
  }

  static let buildTrackInfoDictionaryKey = "MeetPRBuildTrack"

  public static let productionBackendBaseURL = "http://121.40.160.241:3000"

  public static var buildTrack: MeetPRBuildTrack {
    buildTrack(infoDictionary: Bundle.main.infoDictionary)
  }

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

  static func buildTrack(infoDictionary: [String: Any]?) -> MeetPRBuildTrack {
    guard infoDictionary?[buildTrackInfoDictionaryKey] as? String == "Global" else {
      return .china
    }
    return .global
  }
}
