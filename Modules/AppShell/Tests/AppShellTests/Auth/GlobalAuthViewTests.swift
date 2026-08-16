import AuthenticationServices
import Foundation
import Testing
import ViewInspector

@testable import AppShell

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func globalLoginRendersThreeEnglishChannelsAndPrivacyLink() throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let inspected = try GlobalLoginView().environment(session).inspect()
  let renderedText = inspected.findAll(ViewType.Text.self).compactMap { try? $0.string() }
  let privacyURL = try #require(URL(string: "https://meetpr.app/privacy/en"))

  #expect(renderedText.contains("Better than\nyesterday"))
  #expect(renderedText.contains("Continue with Google"))
  #expect(renderedText.contains("or"))
  #expect(renderedText.contains("EMAIL"))
  #expect(renderedText.contains("PASSWORD"))
  #expect(renderedText.contains("Sign in"))
  #expect(renderedText.contains("Create account"))
  #expect(renderedText.contains("Forgot password?"))
  #expect(!renderedText.contains("手机号"))
  #expect(try inspected.find(link: privacyURL).url() == privacyURL)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func authFlowRoutesGlobalTrackToGlobalLogin() throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let inspected = try AuthFlowView(buildTrack: .global).environment(session).inspect()
  let renderedText = inspected.findAll(ViewType.Text.self).compactMap { try? $0.string() }

  #expect(try inspected.find(text: "Continue with Google").string() == "Continue with Google")
  #expect(!renderedText.contains("用手机号和密码登录。"))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func cancellingAppleSignInDoesNotShowErrorToast() async throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let viewModel = GlobalLoginViewModel()
  await viewModel.prepareApple(using: session)
  viewModel.toastMessage = "Sign-in is temporarily unavailable"
  let inspected = try GlobalLoginView(viewModel: viewModel).environment(session).inspect()

  let appleButton = try inspected.find(ViewType.SignInWithAppleButton.self)
  try appleButton.tap(.failure(ASAuthorizationError(.canceled)))
  for _ in 0..<20 where viewModel.toastMessage != nil {
    await Task.yield()
  }

  #expect(viewModel.toastMessage == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func globalRegistrationHasNoRolePicker() throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let inspected = try GlobalRegisterView().environment(session).inspect()
  let renderedText = inspected.findAll(ViewType.Text.self).compactMap { try? $0.string() }

  #expect(renderedText.contains("Create your\naccount"))
  #expect(renderedText.contains("Create account"))
  #expect(!renderedText.contains("Coach"))
  #expect(!renderedText.contains("Self train"))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func forgotPasswordStartsAtEmailStep() throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let inspected = try GlobalForgotPasswordView(onPasswordReset: {}).environment(session).inspect()
  let renderedText = inspected.findAll(ViewType.Text.self).compactMap { try? $0.string() }

  #expect(renderedText.contains("Reset your\npassword"))
  #expect(renderedText.contains("Send code"))
  #expect(!renderedText.contains("Reset password"))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func forgotPasswordResetStepRendersCodeAndNewPassword() throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let viewModel = GlobalForgotPasswordViewModel()
  viewModel.step = .reset
  let inspected = try GlobalForgotPasswordView(viewModel: viewModel, onPasswordReset: {})
    .environment(session)
    .inspect()
  let renderedText = inspected.findAll(ViewType.Text.self).compactMap { try? $0.string() }

  #expect(renderedText.contains("If an account exists, we've sent a code."))
  #expect(renderedText.contains("NEW PASSWORD"))
  #expect(renderedText.contains("Reset password"))
  #expect(throws: Never.self) {
    try inspected.find(viewWithAccessibilityIdentifier: "global.forgot.code").textField()
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func forgotPasswordInvalidCodeRendersToast() async throws {
  let repository = InMemoryAuthRepository(
    forcedError: .backend(statusCode: 401, code: .invalidResetCode, issues: [])
  )
  let session = Session(auth: repository, tokenStore: InMemoryTokenStore())
  let viewModel = GlobalForgotPasswordViewModel()
  viewModel.email = "athlete@example.com"
  viewModel.code = "123456"
  viewModel.newPassword = "new-password123"
  viewModel.step = .reset

  _ = await viewModel.resetPassword(using: session)

  let inspected = try GlobalForgotPasswordView(viewModel: viewModel, onPasswordReset: {})
    .environment(session)
    .inspect()
  #expect(
    try inspected.find(viewWithAccessibilityIdentifier: "global.forgot.toast").text().string()
      == "That code is invalid or has expired"
  )
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func forgotPasswordSuccessInvokesLoginMessageCallback() async throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let viewModel = GlobalForgotPasswordViewModel()
  viewModel.email = "athlete@example.com"
  viewModel.code = "123456"
  viewModel.newPassword = "new-password123"
  viewModel.step = .reset
  let callback = PasswordResetCallbackSpy()
  let sut = GlobalForgotPasswordView(
    viewModel: viewModel,
    session: session,
    onPasswordReset: { callback.record() }
  )
  .environment(session)

  try await ViewHosting.host(sut) {
    let inspected = try sut.inspect()
    try inspected.find(viewWithAccessibilityIdentifier: "global.forgot.reset").button().tap()
    for _ in 0..<20 where !callback.wasCalled {
      await Task.yield()
    }
  }

  #expect(callback.wasCalled)
}

@MainActor
private final class PasswordResetCallbackSpy {
  private(set) var wasCalled = false

  func record() {
    wasCalled = true
  }
}
