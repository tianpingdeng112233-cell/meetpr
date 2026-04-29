import CoreModels
import Foundation
import Observation

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
public final class AuthFormViewModel {
  public enum Mode: Sendable, Equatable {
    case login
    case signup
  }

  public let mode: Mode
  public var phone = ""
  public var password = ""
  public var selectedRole: UserRole?
  public var isSubmitting = false
  public var toastMessage: String?

  public init(mode: Mode) {
    self.mode = mode
  }

  public var phoneError: String? {
    guard !phone.isEmpty, !isPhoneValid else {
      return nil
    }
    return "手机号格式不正确"
  }

  public var passwordError: String? {
    guard !password.isEmpty, !isPasswordValid else {
      return nil
    }
    return "密码至少 8 字符,最多 72 字节"
  }

  public var canSubmit: Bool {
    isPhoneValid && isPasswordValid && isRoleValid
  }

  public func submit(using session: Session) async {
    guard canSubmit else {
      return
    }

    isSubmitting = true
    toastMessage = nil

    do {
      switch mode {
      case .login:
        try await session.login(phone: phone, password: password)
      case .signup:
        guard let selectedRole else {
          isSubmitting = false
          return
        }
        try await session.signup(phone: phone, password: password, role: selectedRole)
      }
    } catch {
      toastMessage = Self.toastMessage(for: error)
    }

    isSubmitting = false
  }

  public static func toastMessage(for error: Error) -> String {
    guard let authError = error as? AuthRepositoryError else {
      return "网络异常,请重试"
    }

    switch authError {
    case .backend(_, .phoneTaken, _):
      return "该手机号已注册"
    case .backend(_, .invalidCredentials, _):
      return "手机号或密码不正确"
    case .backend(_, .validationError, let issues):
      return issues.first?.message ?? "请求参数不正确"
    case .backend(_, .rateLimited, _):
      return "请求过于频繁,请稍后重试"
    case .backend, .decoding, .server:
      return "请求失败,请稍后重试"
    case .network:
      return "网络异常,请重试"
    }
  }

  private var isPhoneValid: Bool {
    phone.range(of: #"^1[3-9]\d{9}$"#, options: .regularExpression) != nil
  }

  private var isPasswordValid: Bool {
    password.count >= 8 && password.utf8.count <= 72
  }

  private var isRoleValid: Bool {
    mode == .login || selectedRole != nil
  }
}
