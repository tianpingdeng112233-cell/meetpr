import Foundation
import Testing

@testable import Networking

@Test func sharedClientHasDefaultBaseURL() {
  #expect(APIClient.shared.baseURL.host() == "api.meetpr.local")
}

@Test func endpointsExposeExpectedPaths() {
  #expect(Endpoint.auth.path == "/auth")
  #expect(Endpoint.authRegister.path == "/auth/register")
  #expect(Endpoint.authLogin.path == "/auth/login")
  #expect(Endpoint.authRefresh.path == "/auth/refresh")
  #expect(Endpoint.coach.path == "/coach")
  #expect(Endpoint.student.path == "/student")
}

@Test func apiClientPostsJSONToConfiguredEndpoint() async throws {
  let capture = NetworkingRequestCapture()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await capture.record(request)
    return APIResponse(data: Data("{}".utf8), statusCode: 200)
  }

  _ = try await client.post(.authLogin, body: Data(#"{"phone":"+8613800000001"}"#.utf8))
  let request = try #require(await capture.request())

  #expect(request.url?.absoluteString == "https://api.test/auth/login")
  #expect(request.httpMethod == "POST")
  #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")
  #expect(request.httpBody == Data(#"{"phone":"+8613800000001"}"#.utf8))
}

private actor NetworkingRequestCapture {
  private var capturedRequest: URLRequest?

  func record(_ request: URLRequest) {
    capturedRequest = request
  }

  func request() -> URLRequest? {
    capturedRequest
  }
}
