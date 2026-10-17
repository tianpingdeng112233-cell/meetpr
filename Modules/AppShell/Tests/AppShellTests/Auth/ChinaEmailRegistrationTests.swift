import Testing
import ViewInspector

@testable import AppShell

@MainActor
@Test func chinaRegistrationRequiresCodeAndMatchingConfirmation() async {
  let model = GlobalRegisterViewModel(buildTrack: .china)
  model.email = "new@example.com"
  model.password = "password123"
  #expect(!model.canSubmit)
  model.code = "123456"
  model.confirmPassword = "different123"
  #expect(!model.canSubmit)
  model.confirmPassword = "password123"
  #expect(model.canSubmit)
}

@MainActor
@Test func changingSignupEmailClearsCodeReceiptAndCooldown() async {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let model = GlobalRegisterViewModel(buildTrack: .china)
  model.email = "first@example.com"
  await model.sendCode(using: session)
  #expect(model.sentEmail == "first@example.com")
  #expect(model.cooldownRemaining == 60)
  #expect(!model.canSendCode)
  model.code = "123456"
  model.email = "second@example.com"
  #expect(model.code.isEmpty)
  #expect(model.sentEmail == nil)
  #expect(model.cooldownRemaining == 0)
  #expect(model.canSendCode)
}

@MainActor
@Test func chinaSignupRejectsInvalidCodeWithoutCreatingSession() async {
  let repository = InMemoryAuthRepository(
    forcedError: .backend(statusCode: 401, code: .invalidSignupCode, issues: []))
  let session = Session(auth: repository, tokenStore: InMemoryTokenStore())
  let model = GlobalRegisterViewModel(buildTrack: .china)
  model.email = "new@example.com"
  model.password = "password123"
  model.confirmPassword = "password123"
  model.code = "123456"
  await model.submit(using: session)
  #expect(session.state == .anonymous)
  #expect(model.codeError != nil)
  #expect(model.canSendCode)
  #expect(model.cooldownRemaining == 0)
}

@MainActor
@Test func signupCooldownExpiresAndNeverBecomesNegative() async {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let model = GlobalRegisterViewModel(buildTrack: .china)
  model.email = "new@example.com"
  await model.sendCode(using: session)
  for _ in 0..<59 { model.tickCooldown() }
  #expect(!model.canSendCode)
  model.tickCooldown()
  #expect(model.canSendCode)
  model.tickCooldown()
  #expect(model.cooldownRemaining == 0)
}

@MainActor
@Test func invalidSignupCodeEndsActiveCooldownAndOffersResend() async {
  let model = GlobalRegisterViewModel(buildTrack: .china)
  model.email = "new@example.com"
  await model.sendCode(
    using: Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore()))
  model.password = "password123"
  model.confirmPassword = "password123"
  model.code = "999999"
  let failed = Session(
    auth: InMemoryAuthRepository(
      forcedError: .backend(statusCode: 401, code: .invalidSignupCode, issues: [])),
    tokenStore: InMemoryTokenStore())
  await model.submit(using: failed)
  #expect(model.codeError != nil)
  #expect(model.canSendCode)
  #expect(model.sentEmail == "new@example.com")
  model.code = "123456"
  #expect(model.codeError == nil)
}

@MainActor
@Test func emailTakenOffersSignInAndEditingEmailClearsIt() async {
  let model = GlobalRegisterViewModel(buildTrack: .china)
  model.email = "existing@example.com"
  model.password = "password123"
  model.confirmPassword = "password123"
  model.code = "123456"
  await model.submit(
    using: Session(
      auth: InMemoryAuthRepository(
        forcedError: .backend(statusCode: 409, code: .emailTaken, issues: [])),
      tokenStore: InMemoryTokenStore()))
  #expect(model.shouldOfferSignIn)
  model.email = "other@example.com"
  #expect(!model.shouldOfferSignIn)
}

@MainActor
@Test func chinaRegistrationLocksAllInputsDuringSubmission() throws {
  let model = GlobalRegisterViewModel(buildTrack: .china)
  model.isSubmitting = true
  let inspected = try GlobalRegisterView(viewModel: model).inspect()
  for identifier in [
    "global.register.email", "china.register.code", "global.register.password",
    "china.register.confirmPassword",
  ] {
    #expect(try inspected.find(viewWithAccessibilityIdentifier: identifier).isDisabled())
  }
}

@MainActor
@Test func invalidSignupCodeReplacesSentReceiptButKeepsSignInHelp() async throws {
  let model = GlobalRegisterViewModel(buildTrack: .china)
  model.email = "new@example.com"
  await model.sendCode(
    using: Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore()))
  model.password = "password123"
  model.confirmPassword = "password123"
  model.code = "999999"
  await model.submit(
    using: Session(
      auth: InMemoryAuthRepository(
        forcedError: .backend(statusCode: 401, code: .invalidSignupCode, issues: [])),
      tokenStore: InMemoryTokenStore()))
  let inspected = try SignupCodeField(viewModel: model, onSendCode: {}, onSignIn: {}).inspect()
  #expect(throws: (any Error).self) {
    try inspected.find(
      text: EmailAuthStrings.text("auth.signupSent", track: .china).replacing(
        "{email}", with: model.email))
  }
  #expect(throws: Never.self) {
    try inspected.find(viewWithAccessibilityIdentifier: "china.register.signInHelp")
  }
}
