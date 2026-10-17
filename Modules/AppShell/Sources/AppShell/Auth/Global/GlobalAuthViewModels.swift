import Foundation
import Networking
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
  static func message(for error: Error, buildTrack: MeetPRBuildTrack = .global) -> String? {
    if let oauthError = error as? GlobalOAuthError, oauthError == .cancelled {
      return nil
    }
    guard let authError = error as? AuthRepositoryError else {
      return EmailAuthStrings.text("auth.unavailable", track: buildTrack)
    }
    switch authError {
    case .backend(_, let code, _):
      return message(for: code, buildTrack: buildTrack)
    case .decoding, .network, .server:
      return EmailAuthStrings.text("auth.unavailable", track: buildTrack)
    }
  }

  private static func message(for code: AuthErrorCode, buildTrack: MeetPRBuildTrack) -> String {
    switch code {
    case .invalidCredentials:
      return EmailAuthStrings.text("auth.invalidCredentials", track: buildTrack)
    case .invalidIdentityToken:
      return EmailAuthStrings.text("auth.invalidIdentityToken", track: buildTrack)
    case .emailTaken:
      return EmailAuthStrings.text("auth.emailTaken", track: buildTrack)
    case .invalidResetCode, .invalidSignupCode:
      return EmailAuthStrings.text("auth.invalidSignupCode", track: buildTrack)
    case .registrationDisabled, .registrationNotAllowed:
      return EmailAuthStrings.text("auth.registrationUnavailable", track: buildTrack)
    case .invalidTimezone:
      return EmailAuthStrings.text("auth.invalidTimezone", track: buildTrack)
    case .rateLimited:
      return EmailAuthStrings.text("auth.rateLimited", track: buildTrack)
    case .validationError:
      return EmailAuthStrings.text("auth.validationError", track: buildTrack)
    case .invalidRefresh, .phoneTaken, .refreshExpired:
      return EmailAuthStrings.text("auth.unavailable", track: buildTrack)
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

  let buildTrack: MeetPRBuildTrack

  init(
    googleOAuth: any GoogleOAuthAuthorizing = GoogleOAuthService(),
    buildTrack: MeetPRBuildTrack = .global
  ) {
    self.buildTrack = buildTrack
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
      toastMessage = GlobalAuthErrorMessage.message(for: error, buildTrack: buildTrack)
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
      toastMessage = GlobalAuthErrorMessage.message(for: error, buildTrack: buildTrack)
    }
    isSubmitting = false
  }
}

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
final class GlobalRegisterViewModel {
  let buildTrack: MeetPRBuildTrack
  var email = "" {
    didSet {
      guard email != oldValue else { return }
      code = ""
      sentEmail = nil
      cooldownRemaining = 0
      toastMessage = nil
      codeError = nil
      shouldOfferSignIn = false
    }
  }
  private(set) var sentEmail: String?
  private(set) var cooldownRemaining = 0
  private(set) var isSendingCode = false

  var canSendCode: Bool {
    GlobalAuthValidation.isValidEmail(email) && cooldownRemaining == 0 && !isSendingCode
      && !isSubmitting
  }

  func tickCooldown() {
    cooldownRemaining = max(0, cooldownRemaining - 1)
  }

  func sendCode(using session: Session) async {
    guard canSendCode else { return }
    let recipient = email
    isSendingCode = true
    toastMessage = nil
    defer { isSendingCode = false }
    do {
      try await session.requestSignupCode(email: recipient)
      guard email == recipient else { return }
      codeError = nil
      sentEmail = recipient
      cooldownRemaining = 60
    } catch {
      guard email == recipient else { return }
      toastMessage = GlobalAuthErrorMessage.message(for: error, buildTrack: buildTrack)
    }
  }
  private(set) var codeError: String?
  private(set) var shouldOfferSignIn = false
  var code = "" { didSet { if code != oldValue { codeError = nil } } }
  var confirmPassword = ""

  init(buildTrack: MeetPRBuildTrack = .global) {
    self.buildTrack = buildTrack
  }
  var password = ""
  var isSubmitting = false
  var toastMessage: String?

  var canSubmit: Bool {
    GlobalAuthValidation.isValidEmail(email)
      && GlobalAuthValidation.isValidPassword(password)
      && (buildTrack == .global
        || (GlobalAuthValidation.isValidResetCode(code) && password == confirmPassword))
      && !isSubmitting
  }

  func submit(using session: Session) async {
    guard canSubmit else { return }
    isSubmitting = true
    toastMessage = nil
    codeError = nil
    shouldOfferSignIn = false
    do {
      try await session.registerWithEmail(
        email: email, password: password, code: buildTrack == .china ? code : nil)
    } catch {
      if buildTrack == .china,
        case .backend(_, let code, _) = error as? AuthRepositoryError
      {
        switch code {
        case .invalidSignupCode:
          codeError = GlobalAuthErrorMessage.message(for: error, buildTrack: buildTrack)
          cooldownRemaining = 0
        case .emailTaken:
          shouldOfferSignIn = true
          toastMessage = GlobalAuthErrorMessage.message(for: error, buildTrack: buildTrack)
        default:
          toastMessage = GlobalAuthErrorMessage.message(for: error, buildTrack: buildTrack)
        }
      } else {
        toastMessage = GlobalAuthErrorMessage.message(for: error, buildTrack: buildTrack)
      }
    }
    isSubmitting = false
  }
}

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
final class GlobalForgotPasswordViewModel {
  let buildTrack: MeetPRBuildTrack
  init(buildTrack: MeetPRBuildTrack = .global) { self.buildTrack = buildTrack }
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
      toastMessage = GlobalAuthErrorMessage.message(for: error, buildTrack: buildTrack)
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
      toastMessage = GlobalAuthErrorMessage.message(for: error, buildTrack: buildTrack)
      isSubmitting = false
      return false
    }
  }
}
