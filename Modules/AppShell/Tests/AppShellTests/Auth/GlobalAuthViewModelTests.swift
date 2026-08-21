import Testing

@testable import AppShell

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func globalEmailLoginAuthenticatesCoachedStudent() async {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let viewModel = GlobalLoginViewModel(googleOAuth: GoogleOAuthStub())
  viewModel.email = "athlete@example.com"
  viewModel.password = "password123"

  await viewModel.signInWithEmail(using: session)

  guard case .authenticated(let user) = session.state else {
    Issue.record("Expected authenticated session")
    return
  }
  #expect(user.role == .coachedStudent)
  #expect(user.phone == "athlete@example.com")
  #expect(viewModel.toastMessage == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func globalGoogleLoginPassesIDTokenThroughSession() async {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let viewModel = GlobalLoginViewModel(
    googleOAuth: GoogleOAuthStub(idToken: "stub-google-token")
  )

  await viewModel.signInWithGoogle(using: session)

  guard case .authenticated(let user) = session.state else {
    Issue.record("Expected authenticated session")
    return
  }
  #expect(user.role == .coachedStudent)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func appleChallengeIsHashedBeforeAuthorizationRequest() async {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let viewModel = GlobalLoginViewModel(googleOAuth: GoogleOAuthStub())

  await viewModel.prepareApple(using: session)

  #expect(
    viewModel.appleNonceHash == GlobalAuthCrypto.sha256Hex("in-memory-challenge")
  )
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func globalRegistrationUsesFixedCoachedStudentRole() async {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let viewModel = GlobalRegisterViewModel()
  viewModel.email = "new-athlete@example.com"
  viewModel.password = "password123"

  await viewModel.submit(using: session)

  guard case .authenticated(let user) = session.state else {
    Issue.record("Expected authenticated session")
    return
  }
  #expect(user.role == .coachedStudent)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func forgotPasswordMovesToCodeThenMapsInvalidCode() async {
  let repository = InMemoryAuthRepository()
  let session = Session(auth: repository, tokenStore: InMemoryTokenStore())
  let viewModel = GlobalForgotPasswordViewModel()
  viewModel.email = "athlete@example.com"

  await viewModel.sendCode(using: session)
  #expect(viewModel.step == .reset)

  await repository.setForcedError(
    .backend(statusCode: 401, code: .invalidResetCode, issues: [])
  )
  viewModel.code = "123456"
  viewModel.newPassword = "new-password123"

  let succeeded = await viewModel.resetPassword(using: session)

  #expect(!succeeded)
  #expect(viewModel.toastMessage == "That code is invalid or has expired")
}

@Test func globalAuthErrorsHaveHumanReadableMessages() {
  let mappings: [(AuthErrorCode, String)] = [
    (.invalidIdentityToken, "We couldn't verify this sign-in. Please try again"),
    (.registrationDisabled, "Account creation is currently unavailable"),
    (.registrationNotAllowed, "Account creation is currently unavailable"),
    (.emailTaken, "An account already exists for this email"),
    (.invalidResetCode, "That code is invalid or has expired"),
    (.invalidTimezone, "Your device timezone isn't supported"),
  ]

  for (code, message) in mappings {
    let error = AuthRepositoryError.backend(statusCode: 400, code: code, issues: [])
    #expect(GlobalAuthErrorMessage.message(for: error) == message)
  }
}

@Test func resetCodeAcceptsOnlySixASCIIDigits() {
  #expect(GlobalAuthValidation.isValidResetCode("123456"))
  #expect(!GlobalAuthValidation.isValidResetCode("12345"))
  #expect(!GlobalAuthValidation.isValidResetCode("１２３４５６"))
  #expect(!GlobalAuthValidation.isValidResetCode("١٢٣٤٥٦"))
  #expect(GlobalAuthValidation.asciiDigits(from: "1２3٤5６") == "135")
}

@MainActor
private struct GoogleOAuthStub: GoogleOAuthAuthorizing {
  var idToken = "google-id-token"

  func authorize() async throws -> String {
    idToken
  }
}
