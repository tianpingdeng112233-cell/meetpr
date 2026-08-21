import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func globalAuthEndpointsExposeBackendPaths() {
  #expect(Endpoint.authChallenge.path == "/auth/challenge")
  #expect(Endpoint.authApple.path == "/auth/apple")
  #expect(Endpoint.authGoogle.path == "/auth/google")
  #expect(Endpoint.authEmailRegister.path == "/auth/email/register")
  #expect(Endpoint.authEmailLogin.path == "/auth/email/login")
  #expect(Endpoint.authEmailForgot.path == "/auth/email/forgot")
  #expect(Endpoint.authEmailReset.path == "/auth/email/reset")
  #expect(Endpoint.meTimezone.path == "/me/timezone")
}

@Test func identityProvidersPinCamelCaseWireContracts() async throws {
  let fixture = makeGlobalAuthFixture()
  let challenge = try await fixture.client.fetchAuthChallenge()
  _ = try await fixture.client.signInWithApple(
    AppleAuthRequestDTO(
      identityToken: "apple-id-token",
      nonce: challenge.nonce,
      role: .coachedStudent,
      authorizationCode: "apple-code",
      timezone: "Europe/London"
    )
  )
  _ = try await fixture.client.signInWithGoogle(
    GoogleAuthRequestDTO(
      idToken: "google-id-token",
      role: .coachedStudent,
      timezone: "Europe/London"
    )
  )

  let requests = await fixture.capture.requests()
  #expect(
    requests.map { $0.url?.path() } == [
      "/auth/challenge", "/auth/apple", "/auth/google",
    ])
  let apple = try jsonBody(requests[1])
  #expect(apple["identityToken"] as? String == "apple-id-token")
  #expect(apple["authorizationCode"] as? String == "apple-code")
  #expect(apple["identity_token"] == nil)
  #expect(apple["timezone"] as? String == "Europe/London")
  let google = try jsonBody(requests[2])
  #expect(google["idToken"] as? String == "google-id-token")
  #expect(google["nonce"] == nil)
}

@Test func emailAndTimezoneEndpointsPinBackendContracts() async throws {
  let fixture = makeGlobalAuthFixture()
  let registration = try await fixture.client.registerWithEmail(
    EmailRegisterRequestDTO(
      email: "athlete@example.com",
      password: "password123",
      role: .coachedStudent,
      timezone: "Europe/London"
    )
  )
  _ = try await fixture.client.loginWithEmail(
    EmailLoginRequestDTO(email: "athlete@example.com", password: "password123")
  )
  try await fixture.client.requestPasswordReset(
    EmailForgotRequestDTO(email: "athlete@example.com")
  )
  try await fixture.client.resetPassword(
    EmailResetRequestDTO(
      email: "athlete@example.com",
      code: "123456",
      newPassword: "new-password123"
    )
  )
  try await fixture.client.updateTimezone("Europe/London", accessToken: "access-token")

  #expect(registration.user.phone == nil)
  #expect(registration.user.email == "athlete@example.com")
  #expect(try registration.user.toUser().phone == "athlete@example.com")

  let requests = await fixture.capture.requests()
  #expect(
    requests.map { $0.url?.path() } == [
      "/auth/email/register", "/auth/email/login", "/auth/email/forgot", "/auth/email/reset",
      "/me/timezone",
    ])
  #expect(requests.map(\.httpMethod) == ["POST", "POST", "POST", "POST", "PATCH"])
  let reset = try jsonBody(requests[3])
  #expect(reset["newPassword"] as? String == "new-password123")
  #expect(reset["new_password"] == nil)
  let timezone = try jsonBody(requests[4])
  #expect(timezone["timezone"] as? String == "Europe/London")
  #expect(requests[4].value(forHTTPHeaderField: "authorization") == "Bearer access-token")
}

private func makeGlobalAuthFixture() -> (
  client: APIClient, capture: GlobalAuthRequestCapture
) {
  let capture = GlobalAuthRequestCapture()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await capture.record(request)
    let requestPath = request.url?.path()
    if requestPath == Endpoint.authChallenge.path {
      return APIResponse(
        data: Data(
          #"{"nonce":"plain-nonce","expiresAt":"2026-08-16T00:10:00.000Z"}"#.utf8),
        statusCode: 200
      )
    }
    if requestPath == Endpoint.authEmailForgot.path || requestPath == Endpoint.authEmailReset.path
      || requestPath == Endpoint.meTimezone.path
    {
      return APIResponse(data: Data(), statusCode: 204)
    }
    return APIResponse(data: globalAuthResultData, statusCode: 200)
  }
  return (client, capture)
}

private let globalAuthResultData = Data(
  """
  {
    "user": {
      "id": "00000000-0000-4000-8000-000000000074",
      "phone": null,
      "email": "athlete@example.com",
      "role": "coached_student",
      "createdAt": "2026-08-16T00:00:00.000Z"
    },
    "accessToken": "access-token",
    "refreshToken": "refresh-token"
  }
  """.utf8
)

private func jsonBody(_ request: URLRequest) throws -> [String: Any] {
  let body = try #require(request.httpBody)
  return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
}

private actor GlobalAuthRequestCapture {
  private var capturedRequests: [URLRequest] = []

  func record(_ request: URLRequest) {
    capturedRequests.append(request)
  }

  func requests() -> [URLRequest] {
    capturedRequests
  }
}
