public enum Endpoint: Equatable, Sendable {
  case auth
  case coach
  case student

  public var path: String {
    switch self {
    case .auth:
      "/auth"
    case .coach:
      "/coach"
    case .student:
      "/student"
    }
  }
}
