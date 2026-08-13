import CoreModels
import Foundation
import Networking
import Testing

@testable import AppShell

@available(iOS 17.0, macOS 14.0, *)
@Test func signupPrependsChinaCodeAndMapsUserDefaults() async throws {
  let capture = RequestCapture()
  let api = try APIClient.stub(data: AuthTestSupport.authResultData(), capture: capture)
  let repository = NetworkingAuthRepository(api: api)

  let result = try await repository.signup(
    phone: "13800000001",
    password: "password123",
    role: .coach
  )
  let body = try #require(await capture.body())
  let request = try MeetPRCodec.decoder.decode(AuthRegisterRequestDTO.self, from: body)

  #expect(request.phone == "+8613800000001")
  #expect(request.role == .coach)
  #expect(result.user.phone == "+8613800000001")
  #expect(result.user.name == nil)
  #expect(result.user.unitSystem == .metric)
  #expect(result.user.updatedAt == result.user.createdAt)
  #expect(result.accessToken == "access-token")
  #expect(result.refreshToken == "refresh-token")
}

@available(iOS 17.0, macOS 14.0, *)
@Test func signupPreservesGlobalE164PhoneNumber() async throws {
  let capture = RequestCapture()
  let api = try APIClient.stub(data: AuthTestSupport.authResultData(), capture: capture)
  let repository = NetworkingAuthRepository(api: api)

  _ = try await repository.signup(
    phone: "+14155550123",
    password: "password123",
    role: .coach
  )
  let body = try #require(await capture.body())
  let request = try MeetPRCodec.decoder.decode(AuthRegisterRequestDTO.self, from: body)

  #expect(request.phone == "+14155550123")
}

@available(iOS 17.0, macOS 14.0, *)
@Test func loginPrependsChinaCodeAndMapsTokens() async throws {
  let capture = RequestCapture()
  let api = try APIClient.stub(
    data: AuthTestSupport.authResultData(
      accessToken: "login-access", refreshToken: "login-refresh"),
    capture: capture
  )
  let repository = NetworkingAuthRepository(api: api)

  let result = try await repository.login(phone: "13800000001", password: "password123")
  let body = try #require(await capture.body())
  let request = try MeetPRCodec.decoder.decode(AuthLoginRequestDTO.self, from: body)

  #expect(request.phone == "+8613800000001")
  #expect(request.password == "password123")
  #expect(result.accessToken == "login-access")
  #expect(result.refreshToken == "login-refresh")
}

@available(iOS 17.0, macOS 14.0, *)
@Test func refreshMapsTokenPair() async throws {
  let capture = RequestCapture()
  let api = try APIClient.stub(data: AuthTestSupport.refreshData(), capture: capture)
  let repository = NetworkingAuthRepository(api: api)

  let tokens = try await repository.refresh(refreshToken: "old-refresh")
  let body = try #require(await capture.body())
  let request = try MeetPRCodec.decoder.decode(AuthRefreshRequestDTO.self, from: body)

  #expect(request.refreshToken == "old-refresh")
  #expect(tokens == TokenPair(accessToken: "new-access-token", refreshToken: "new-refresh-token"))
}

@available(iOS 17.0, macOS 14.0, *)
@Test func mapsPhoneTakenErrorCode() async throws {
  let repository = try repositoryReturningError(statusCode: 409, code: "AUTH_PHONE_TAKEN")

  await #expect(throws: AuthRepositoryError.backend(statusCode: 409, code: .phoneTaken, issues: []))
  {
    try await repository.signup(phone: "13800000001", password: "password123", role: .coach)
  }
}

@available(iOS 17.0, macOS 14.0, *)
@Test func mapsInvalidCredentialsErrorCode() async throws {
  let repository = try repositoryReturningError(statusCode: 401, code: "AUTH_INVALID_CREDENTIALS")

  await #expect(
    throws: AuthRepositoryError.backend(statusCode: 401, code: .invalidCredentials, issues: [])
  ) {
    try await repository.login(phone: "13800000001", password: "wrongpass")
  }
}

@available(iOS 17.0, macOS 14.0, *)
@Test func mapsValidationErrorIssues() async throws {
  let issue = AuthValidationIssueDTO(path: ["phone"], message: "Phone must be E.164 format")
  let repository = try repositoryReturningError(
    statusCode: 400,
    code: "VALIDATION_ERROR",
    issues: [issue]
  )

  await #expect(
    throws: AuthRepositoryError.backend(
      statusCode: 400,
      code: .validationError,
      issues: [AuthValidationIssue(path: ["phone"], message: "Phone must be E.164 format")]
    )
  ) {
    try await repository.signup(phone: "13800000001", password: "password123", role: .coach)
  }
}

@available(iOS 17.0, macOS 14.0, *)
@Test func mapsRateLimitedErrorCode() async throws {
  let repository = try repositoryReturningError(statusCode: 429, code: "RATE_LIMITED")

  await #expect(
    throws: AuthRepositoryError.backend(statusCode: 429, code: .rateLimited, issues: [])
  ) {
    try await repository.login(phone: "13800000001", password: "password123")
  }
}

@available(iOS 17.0, macOS 14.0, *)
private func repositoryReturningError(
  statusCode: Int,
  code: String,
  issues: [AuthValidationIssueDTO]? = nil
) throws -> NetworkingAuthRepository {
  let data = try AuthTestSupport.errorData(code: code, issues: issues)
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { _ in
    APIResponse(data: data, statusCode: statusCode)
  }
  return NetworkingAuthRepository(api: api)
}

extension APIClient {
  fileprivate static func stub(data: Data, capture: RequestCapture) throws -> APIClient {
    APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
      await capture.record(request)
      return APIResponse(data: data, statusCode: 200)
    }
  }
}
