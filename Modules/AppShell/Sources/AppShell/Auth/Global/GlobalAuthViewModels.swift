import Foundation
import Observation

enum GlobalAuthValidation {
  static func isValidEmail(_ email: String) -> Bool {
    let parts = email.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty else { return false }
    let domainParts = parts[1].split(separator: ".", omittingEmptySubsequences: false)
    return domainParts.count >= 2 && domainParts.allSatisfy { !$0.isEmpty }
  }

  static func isValidPassword(_ password: String) -> Bool {
    password.count >= 8 && password.utf8.count <= 72
  }

  static func asciiDigits(from input: String) -> String {
    String(input.filter { ("0"..."9").contains($0) })
  }

  static func isValidResetCode(_ code: String) -> Bool {
    code.count == 6 && asciiDigits(from: code) == code
  }
}

enum GlobalAuthErrorMessage {
  static func message(for error: Error) -> String? {
    if let oauthError = error as? GlobalOAuthError, oauthError == .cancelled {
      return nil
    }
    guard let authError = error as? AuthRepositoryError else {
      return "Sign-in is temporarily unavailable"
    }
    switch authError {
    case .backend(_, let code, _):
      return message(for: code)
    case .decoding, .network, .server:
      return "Sign-in is temporarily unavailable"
    }
  }

  private static func message(for code: AuthErrorCode) -> String {
    switch code {
    case .invalidCredentials:
      return "Incorrect email or password"
    case .invalidIdentityToken:
      return "We couldn't verify this sign-in. Please try again"
    case .emailTaken:
      return "An account already exists for this email"
    case .invalidResetCode:
      return "That code is invalid or has expired"
    case .registrationDisabled, .registrationNotAllowed:
      return "Account creation is currently unavailable"
    case .invalidTimezone:
      return "Your device timezone isn't supported"
    case .rateLimited:
      return "Too many attempts. Please try again later"
    case .validationError:
      return "Check your details and try again"
    case .invalidRefresh, .phoneTaken, .refreshExpired:
      return "Sign-in is temporarily unavailable"
    }
  }
}

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
final class GlobalLoginViewModel {
  var email = ""
  var password = ""
  var isSubmitting = false
  var toastMessage: String?
  private(set) var appleChallenge: AuthChallenge?

  @ObservationIgnored private let googleOAuth: any GoogleOAuthAuthorizing

  init(googleOAuth: any GoogleOAuthAuthorizing = GoogleOAuthService()) {
    self.googleOAuth = googleOAuth
  }

  var canSubmitEmail: Bool {
    GlobalAuthValidation.isValidEmail(email)
      && GlobalAuthValidation.isValidPassword(password)
      && !isSubmitting
  }

  var appleNonceHash: String? {
    guard let appleChallenge, appleChallenge.expiresAt > Date() else { return nil }
    return GlobalAuthCrypto.sha256Hex(appleChallenge.nonce)
  }

  func prepareApple(using session: Session) async {
    if appleNonceHash != nil { return }
    do {
      appleChallenge = try await session.fetchAuthChallenge()
    } catch {
      toastMessage = GlobalAuthErrorMessage.message(for: error)
    }
  }

  func signInWithEmail(using session: Session) async {
    guard canSubmitEmail else { return }
    await submit {
      try await session.loginWithEmail(email: email, password: password)
    }
  }

  func signInWithGoogle(using session: Session) async {
    guard !isSubmitting else { return }
    await submit {
      let idToken = try await googleOAuth.authorize()
      try await session.signInWithGoogle(idToken: idToken)
    }
  }

  func signInWithApple(
    identityToken: String,
    authorizationCode: String?,
    using session: Session
  ) async {
    guard let challenge = appleChallenge, challenge.expiresAt > Date(), !isSubmitting else {
      appleChallenge = nil
      await prepareApple(using: session)
      return
    }
    await submit {
      try await session.signInWithApple(
        identityToken: identityToken,
        nonce: challenge.nonce,
        authorizationCode: authorizationCode
      )
    }
    appleChallenge = nil
    if case .anonymous = session.state {
      await prepareApple(using: session)
    }
  }

  private func submit(_ operation: () async throws -> Void) async {
    isSubmitting = true
    toastMessage = nil
    do {
      try await operation()
    } catch {
      toastMessage = GlobalAuthErrorMessage.message(for: error)
    }
    isSubmitting = false
  }
}

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
final class GlobalRegisterViewModel {
  var email = ""
  var password = ""
  var isSubmitting = false
  var toastMessage: String?

  var canSubmit: Bool {
    GlobalAuthValidation.isValidEmail(email)
      && GlobalAuthValidation.isValidPassword(password)
      && !isSubmitting
  }

  func submit(using session: Session) async {
    guard canSubmit else { return }
    isSubmitting = true
    toastMessage = nil
    do {
      try await session.registerWithEmail(email: email, password: password)
    } catch {
      toastMessage = GlobalAuthErrorMessage.message(for: error)
    }
    isSubmitting = false
  }
}

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
final class GlobalForgotPasswordViewModel {
  enum Step: Sendable, Equatable {
    case email
    case reset
  }

  var email = ""
  var code = ""
  var newPassword = ""
  var step: Step = .email
  var isSubmitting = false
  var toastMessage: String?

  var canSendCode: Bool {
    GlobalAuthValidation.isValidEmail(email) && !isSubmitting
  }

  var canResetPassword: Bool {
    GlobalAuthValidation.isValidResetCode(code)
      && GlobalAuthValidation.isValidPassword(newPassword)
      && !isSubmitting
  }

  func sendCode(using session: Session) async {
    guard canSendCode else { return }
    isSubmitting = true
    toastMessage = nil
    do {
      try await session.requestPasswordReset(email: email)
      step = .reset
    } catch {
      toastMessage = GlobalAuthErrorMessage.message(for: error)
    }
    isSubmitting = false
  }

  func resetPassword(using session: Session) async -> Bool {
    guard canResetPassword else { return false }
    isSubmitting = true
    toastMessage = nil
    do {
      try await session.resetPassword(email: email, code: code, newPassword: newPassword)
      isSubmitting = false
      return true
    } catch {
      toastMessage = GlobalAuthErrorMessage.message(for: error)
      isSubmitting = false
      return false
    }
  }
}
