public enum Endpoint: Equatable, Sendable {
  case auth
  case authLogin
  case authRefresh
  case authRegister
  case coach
  case student

  public var path: String {
    switch self {
    case .auth:
      "/auth"
    case .authLogin:
      "/auth/login"
    case .authRefresh:
      "/auth/refresh"
    case .authRegister:
      "/auth/register"
    case .coach:
      "/coach"
    case .student:
      "/student"
    }
  }
}
