import CoreModels
import Testing

@testable import AppShell

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func validatesChineseNationalPhoneNumbers() {
  let viewModel = AuthFormViewModel(mode: .login)

  #expect(viewModel.phoneHelperText == "中国大陆 11 位手机号")
  #expect(viewModel.phonePrefix == "+86")
  #expect(viewModel.loginPhonePlaceholder == "138 0000 0001")
  #expect(viewModel.signupPhonePlaceholder == "13800000001")

  viewModel.phone = "12800000001"
  #expect(viewModel.phoneError == "手机号格式不正确")
  #expect(!viewModel.canSubmit)

  viewModel.phone = "13800000001"
  viewModel.password = "password123"
  #expect(viewModel.phoneError == nil)
  #expect(viewModel.canSubmit)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func validatesPasswordLengthAndBcryptByteLimit() {
  let viewModel = AuthFormViewModel(mode: .login)
  viewModel.phone = "13800000001"

  viewModel.password = "1234567"
  #expect(viewModel.passwordError == "密码至少 8 字符,最多 72 字节")
  #expect(!viewModel.canSubmit)

  viewModel.password = String(repeating: "a", count: 72)
  #expect(viewModel.passwordError == nil)
  #expect(viewModel.canSubmit)

  viewModel.password = String(repeating: "a", count: 73)
  #expect(viewModel.passwordError == "密码至少 8 字符,最多 72 字节")
  #expect(!viewModel.canSubmit)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func signupRequiresRoleButLoginDoesNot() {
  let signup = AuthFormViewModel(mode: .signup)
  signup.phone = "13800000001"
  signup.password = "password123"

  #expect(!signup.canSubmit)

  signup.selectedRole = .coach
  #expect(signup.canSubmit)

  let login = AuthFormViewModel(mode: .login)
  login.phone = "13800000001"
  login.password = "password123"

  #expect(login.canSubmit)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func mapsAuthErrorsToChineseToastMessages() {
  #expect(
    AuthFormViewModel.toastMessage(
      for: AuthRepositoryError.backend(statusCode: 409, code: .phoneTaken, issues: [])
    ) == "该手机号已注册"
  )
  #expect(
    AuthFormViewModel.toastMessage(
      for: AuthRepositoryError.backend(statusCode: 401, code: .invalidCredentials, issues: [])
    ) == "手机号或密码错误"
  )
  #expect(
    AuthFormViewModel.toastMessage(
      for: AuthRepositoryError.backend(statusCode: 429, code: .rateLimited, issues: [])
    ) == "请求过于频繁,请稍后重试"
  )
  #expect(AuthFormViewModel.toastMessage(for: AuthRepositoryError.network) == "网络不稳定,重试")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func validationErrorToastUsesFirstBackendIssue() {
  let issue = AuthValidationIssue(path: ["phone"], message: "Phone must be E.164 format")

  let message = AuthFormViewModel.toastMessage(
    for: AuthRepositoryError.backend(statusCode: 400, code: .validationError, issues: [issue])
  )

  #expect(message == "手机号格式不对(+86 开头)")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func submitFailureStopsLoadingAndStoresToast() async {
  let repository = InMemoryAuthRepository(
    forcedError: .backend(statusCode: 409, code: .phoneTaken, issues: [])
  )
  let session = Session(auth: repository, tokenStore: InMemoryTokenStore())
  let viewModel = AuthFormViewModel(mode: .signup)
  viewModel.phone = "13800000001"
  viewModel.password = "password123"
  viewModel.selectedRole = .coach

  await viewModel.submit(using: session)

  #expect(!viewModel.isSubmitting)
  #expect(viewModel.toastMessage == "该手机号已注册")
  #expect(session.state == .anonymous)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func submitSuccessAuthenticatesThroughSession() async {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  let viewModel = AuthFormViewModel(mode: .signup)
  viewModel.phone = "13800000001"
  viewModel.password = "password123"
  viewModel.selectedRole = .selfTrainStudent

  await viewModel.submit(using: session)

  guard case .authenticated(let user) = session.state else {
    Issue.record("Expected authenticated state after submit")
    return
  }

  #expect(user.role == .selfTrainStudent)
  #expect(viewModel.toastMessage == nil)
  #expect(!viewModel.isSubmitting)
}
