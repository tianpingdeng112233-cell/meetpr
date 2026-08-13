import Foundation

public enum PhoneValidationStyle: Sendable, Equatable {
  case mainlandChina
  case globalE164

  public var regularExpression: String {
    switch self {
    case .mainlandChina:
      #"^1[3-9]\d{9}$"#
    case .globalE164:
      #"^\+[1-9]\d{7,14}$"#
    }
  }
}

public enum BuildConfig {
  static let buildTrackInfoDictionaryKey = "MeetPRBuildTrack"

  public static let productionBackendBaseURL = "http://121.40.160.241:3000"

  public static var phoneValidationStyle: PhoneValidationStyle {
    phoneValidationStyle(infoDictionary: Bundle.main.infoDictionary)
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

  static func phoneValidationStyle(infoDictionary: [String: Any]?) -> PhoneValidationStyle {
    guard infoDictionary?[buildTrackInfoDictionaryKey] as? String == "Global" else {
      return .mainlandChina
    }
    return .globalE164
  }
}
