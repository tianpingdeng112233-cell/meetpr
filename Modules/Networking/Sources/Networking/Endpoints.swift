public enum Endpoint: Equatable, Sendable {
  case auth
  case authApple
  case authChallenge
  case authEmailForgot
  case authEmailLogin
  case authEmailRegister
  case authEmailReset
  case authGoogle
  case authLogin
  case authRefresh
  case authRegister
  case coach
  case meTimezone
  case student

  public var path: String {
    switch self {
    case .auth:
      "/auth"
    case .authApple:
      "/auth/apple"
    case .authChallenge:
      "/auth/challenge"
    case .authEmailForgot:
      "/auth/email/forgot"
    case .authEmailLogin:
      "/auth/email/login"
    case .authEmailRegister:
      "/auth/email/register"
    case .authEmailReset:
      "/auth/email/reset"
    case .authGoogle:
      "/auth/google"
    case .authLogin:
      "/auth/login"
    case .authRefresh:
      "/auth/refresh"
    case .authRegister:
      "/auth/register"
    case .coach:
      "/coach"
    case .meTimezone:
      "/me/timezone"
    case .student:
      "/student"
    }
  }
}
