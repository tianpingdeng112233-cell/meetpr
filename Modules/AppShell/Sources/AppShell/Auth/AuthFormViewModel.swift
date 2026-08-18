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

  public var phoneHelperText: String {
    AppShellStrings.phoneHelper
  }

  public var phonePrefix: String? {
    "+86"
  }

  public var loginPhonePlaceholder: String {
    "138 0000 0001"
  }

  public var signupPhonePlaceholder: String {
    "13800000001"
  }

  public var phoneError: String? {
    guard !phone.isEmpty, !isPhoneValid else {
      return nil
    }
    return AppShellStrings.invalidPhone
  }

  public var passwordError: String? {
    guard !password.isEmpty, !isPasswordValid else {
      return nil
    }
    return AppShellStrings.invalidPassword
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
      return AppShellStrings.networkUnstable
    }

    switch authError {
    case .backend(_, .phoneTaken, _):
      return AppShellStrings.phoneTaken
    case .backend(_, .invalidCredentials, _):
      return AppShellStrings.invalidCredentials
    case .backend(_, .validationError, _):
      return AppShellStrings.invalidPhoneWithPrefix
    case .backend(_, .rateLimited, _):
      return AppShellStrings.rateLimited
    case .backend, .decoding, .server:
      return AppShellStrings.requestFailed
    case .network:
      return AppShellStrings.networkUnstable
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
