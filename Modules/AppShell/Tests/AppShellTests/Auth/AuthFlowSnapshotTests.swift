import Testing
import ViewInspector

@testable import AppShell

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func loginViewRendersPhonePasswordAndSubmitButton() throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let sut = LoginView().environment(session)
  let inspected = try sut.inspect()

  #expect(try inspected.find(text: "Better than\nyesterday").string() == "Better than\nyesterday")
  #expect(try inspected.find(text: "用手机号和密码登录。").string() == "用手机号和密码登录。")
  #expect(try inspected.find(text: "手机号").string() == "手机号")
  #expect(try inspected.find(text: "+86").string() == "+86")
  #expect(try inspected.find(text: "密码").string() == "密码")
  #expect(try inspected.find(text: "登录").string() == "登录")
  #expect(try inspected.find(text: "继续即表示同意").string() == "继续即表示同意")
  #expect(try inspected.find(text: "隐私政策").string() == "隐私政策")
  #expect(
    try inspected.find(link: AnalyticsPrivacyNotice.privacyPolicyURL).url()
      == AnalyticsPrivacyNotice.privacyPolicyURL
  )
  #expect(
    try inspected.find(viewWithAccessibilityLabel: "显示密码").accessibilityLabel().string()
      == "显示密码"
  )
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func loginViewOmitsDeferredAndDeadEndActions() throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let inspected = try LoginView().environment(session).inspect()
  let renderedText = inspected.findAll(ViewType.Text.self).compactMap { try? $0.string() }

  #expect(!renderedText.contains("忘记密码？"))
  #expect(!renderedText.contains("忘记密码?"))
  #expect(!renderedText.contains("使用 Apple ID 登录"))
  #expect(!renderedText.contains("中国大陆 11 位手机号"))
  #expect(!renderedText.contains("服务条款"))
}

/// An empty form must not offer a submittable CTA.
///
/// Scope note: this pins the *behaviour* only. The matching visual regression
/// (a self-drawn button plus a bare `.disabled()`, which leaves a custom gold
/// background fully lit) is not reachable from here — asserting the fill would
/// mean reading a modifier off a private subview — so it is covered by the
/// disabled-state simulator screenshot in the PR. Driving the enabled case
/// needs `ViewHosting` to pump `LoginView`'s private view model, which no test
/// in this repo does.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func loginSubmitIsDisabledForEmptyForm() throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let inspected = try LoginView().environment(session).inspect()
  let submit = try inspected.find(viewWithAccessibilityIdentifier: "login.submit").button()

  #expect(submit.isDisabled())
}

/// The reveal control starts masked and is reachable as a real button.
///
/// Driving the toggle itself would need `ViewHosting` to pump the private
/// `@State` inside `AuthSecureField`; no test in this repo uses it, so the
/// plain-text render is covered by the simulator screenshot in the PR instead.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func passwordStartsMaskedWithAReachableRevealButton() throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let inspected = try LoginView().environment(session).inspect()
  let reveal = try inspected.find(viewWithAccessibilityLabel: "显示密码")

  #expect(try reveal.accessibilityLabel().string() == "显示密码")
  #expect(throws: Never.self) { try reveal.button() }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func authFlowStartsAtLogin() throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let sut = AuthFlowView().environment(session)
  let inspected = try sut.inspect()

  #expect(try inspected.find(text: "Better than\nyesterday").string() == "Better than\nyesterday")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func signupViewRendersThreeRoleOptions() throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let sut = SignupView().environment(session)
  let inspected = try sut.inspect()

  #expect(try inspected.find(text: "选择你的角色").string() == "选择你的角色")
  #expect(try inspected.find(text: "教练").string() == "教练")
  #expect(try inspected.find(text: "学员 · 有教练").string() == "学员 · 有教练")
  #expect(try inspected.find(text: "学员 · 自己练").string() == "学员 · 自己练")
}
