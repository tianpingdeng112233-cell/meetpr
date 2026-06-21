import Testing
import ViewInspector

@testable import AppShell

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func loginViewRendersPhonePasswordAndSubmitButton() throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let sut = LoginView().environment(session)
  let inspected = try sut.inspect()

  #expect(try inspected.find(text: "Better").string() == "Better")
  #expect(try inspected.find(text: "手机号").string() == "手机号")
  #expect(try inspected.find(text: "密码").string() == "密码")
  #expect(try inspected.find(text: "登录").string() == "登录")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func authFlowStartsAtLogin() throws {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let sut = AuthFlowView().environment(session)
  let inspected = try sut.inspect()

  #expect(try inspected.find(text: "Better").string() == "Better")
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
