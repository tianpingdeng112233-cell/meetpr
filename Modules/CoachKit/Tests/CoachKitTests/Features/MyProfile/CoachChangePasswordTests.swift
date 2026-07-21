import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import CoachKit

@MainActor
@Test func coachChangePasswordValidatesLocallyAndMapsMismatch() async throws {
  let repository = InMemoryCoachAccountRepository(password: "right-pass-1")
  let viewModel = CoachChangePasswordViewModel(account: repository)

  viewModel.oldPassword = "wrong-pass-1"
  viewModel.newPassword = "short"
  viewModel.confirmPassword = "short"
  #expect(!viewModel.canSubmit)
  #expect(viewModel.localValidationMessage == "新密码至少 8 位")

  viewModel.newPassword = "new-pass-123"
  viewModel.confirmPassword = "new-pass-124"
  #expect(!viewModel.canSubmit)
  #expect(viewModel.localValidationMessage == "两次输入的新密码不一致")

  viewModel.confirmPassword = "new-pass-123"
  await viewModel.submit()
  #expect(viewModel.state == .failed("旧密码不正确"))

  viewModel.oldPassword = "right-pass-1"
  await viewModel.submit()
  #expect(viewModel.state == .saved)
  #expect(await repository.currentPassword() == "new-pass-123")
}

@MainActor
@Test func coachChangePasswordMapsUnexpectedFailureToRetryMessage() async {
  let viewModel = CoachChangePasswordViewModel(account: FailingCoachAccountRepository())
  viewModel.oldPassword = "right-pass-1"
  viewModel.newPassword = "new-pass-123"
  viewModel.confirmPassword = "new-pass-123"

  await viewModel.submit()

  #expect(viewModel.state == .failed("修改失败,请检查网络后重试"))
  #expect(viewModel.canSubmit)
}

@Test func backendCoachAccountRepositorySendsPasswordChangeRequest() async throws {
  let recorder = CoachAccountRequestRecorder()
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await recorder.record(request)
    return APIResponse(data: Data(), statusCode: 204)
  }
  let repository = BackendCoachAccountRepository(api: api, session: CoachAccountSessionReader())

  try await repository.changePassword(old: "old-pass-123", new: "new-pass-123")

  let request = try #require(await recorder.request)
  #expect(request.httpMethod == "PUT")
  #expect(request.url?.path == "/me/password")
  #expect(request.value(forHTTPHeaderField: "authorization") == "Bearer token")
  let body = try #require(request.httpBody)
  let object = try #require(
    JSONSerialization.jsonObject(with: body) as? [String: String]
  )
  #expect(object == ["old_password": "old-pass-123", "new_password": "new-pass-123"])
}

@Test func backendCoachAccountRepositoryMapsPasswordMismatchEnvelope() async throws {
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { _ in
    APIResponse(data: Data(#"{"error":"PASSWORD_MISMATCH"}"#.utf8), statusCode: 403)
  }
  let repository = BackendCoachAccountRepository(api: api, session: CoachAccountSessionReader())

  await #expect(throws: AccountRepositoryError.passwordMismatch) {
    try await repository.changePassword(old: "wrong-pass", new: "new-pass-123")
  }
}

private struct FailingCoachAccountRepository: AccountRepository {
  func deleteAccount() async throws {
    throw URLError(.notConnectedToInternet)
  }

  func changePassword(old: String, new: String) async throws {
    throw URLError(.notConnectedToInternet)
  }
}

private struct CoachAccountSessionReader: SessionStateReader {
  func accessToken() async throws -> String {
    "token"
  }

  func currentUser() async throws -> User {
    throw SessionStateReaderError.missingCurrentUser
  }
}

private actor CoachAccountRequestRecorder {
  private(set) var request: URLRequest?

  func record(_ request: URLRequest) {
    self.request = request
  }
}
