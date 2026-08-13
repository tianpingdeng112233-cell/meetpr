import CoreModels
import Foundation
import Networking
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
  public let phoneValidationStyle: PhoneValidationStyle
  public var phone = ""
  public var password = ""
  public var selectedRole: UserRole?
  public var isSubmitting = false
  public var toastMessage: String?

  public init(
    mode: Mode,
    phoneValidationStyle: PhoneValidationStyle = BuildConfig.phoneValidationStyle
  ) {
    self.mode = mode
    self.phoneValidationStyle = phoneValidationStyle
  }

  public var phoneHelperText: String {
    switch phoneValidationStyle {
    case .mainlandChina:
      "中国大陆 11 位手机号"
    case .globalE164:
      "International phone number in E.164 format"
    }
  }

  public var phonePrefix: String? {
    switch phoneValidationStyle {
    case .mainlandChina:
      "+86"
    case .globalE164:
      nil
    }
  }

  public var loginPhonePlaceholder: String {
    switch phoneValidationStyle {
    case .mainlandChina:
      "138 0000 0001"
    case .globalE164:
      "+14155550123"
    }
  }

  public var signupPhonePlaceholder: String {
    switch phoneValidationStyle {
    case .mainlandChina:
      "13800000001"
    case .globalE164:
      "+14155550123"
    }
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
      return "网络不稳定,重试"
    }

    switch authError {
    case .backend(_, .phoneTaken, _):
      return "该手机号已注册"
    case .backend(_, .invalidCredentials, _):
      return "手机号或密码错误"
    case .backend(_, .validationError, _):
      return "手机号格式不对(+86 开头)"
    case .backend(_, .rateLimited, _):
      return "请求过于频繁,请稍后重试"
    case .backend, .decoding, .server:
      return "请求失败,请稍后重试"
    case .network:
      return "网络不稳定,重试"
    }
  }

  private var isPhoneValid: Bool {
    phone.range(of: phoneValidationStyle.regularExpression, options: .regularExpression) != nil
  }

  private var isPasswordValid: Bool {
    password.count >= 8 && password.utf8.count <= 72
  }

  private var isRoleValid: Bool {
    mode == .login || selectedRole != nil
  }
}
