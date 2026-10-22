import Foundation
import Testing

@testable import Networking

@Test func sharedClientHasDefaultBaseURL() {
  #expect(APIClient.shared.baseURL.absoluteString == "http://121.40.160.241:3000")
}

@Test func buildConfigUsesEnvironmentBaseURLWhenPresent() {
  let url = BuildConfig.backendBaseURL(environment: ["MEETPR_API_BASE_URL": "http://demo.invalid"])

  #expect(url.absoluteString == "http://demo.invalid")
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

@Test func apiRequestsNegotiateLocaleAndPreserveSessionLanguageHeader() async throws {
  let capture = NetworkingRequestCapture()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await capture.record(request)
    return APIResponse(data: Data("{}".utf8), statusCode: 200)
  }
  _ = try await client.getResponse(
    path: "/plans", accessToken: "token", headers: ["Accept-Language": "zh-Hant-TW,en;q=0.9"])
  let request = try #require(await capture.request())
  let language = try #require(request.value(forHTTPHeaderField: "X-MeetPR-Locale"))
  #expect(["zh-Hans", "zh-Hant", "en"].contains(language))
  #expect(request.value(forHTTPHeaderField: "Accept-Language") == "zh-Hant-TW,en;q=0.9")
}

@Test(arguments: [
  ("zh-Hant", "zh-Hant"), ("zh-Hant-TW", "zh-Hant"), ("zh_TW", "zh-Hant"),
  ("zh-HK", "zh-Hant"), ("zh-MO", "zh-Hant"), ("zh-Hans", "zh-Hans"),
  ("zh-Hans-TW", "zh-Hans"), ("zh-Hant-CN", "zh-Hant"),
  ("zh-CN", "zh-Hans"), ("zh", "zh-Hans"), ("en-GB", "en"), ("fr", "en"),
])
func apiRequestsUseOneNegotiatedLanguage(localization: String, expected: String) async throws {
  let client = APIClient(
    environment: ["MEETPR_API_BASE_URL": "https://api.test"],
    preferredLocalization: localization
  ) { request in
    #expect(request.value(forHTTPHeaderField: "X-MeetPR-Locale") == expected)
    #expect(request.value(forHTTPHeaderField: "Accept-Language") == nil)
    return APIResponse(data: Data("{}".utf8), statusCode: 200)
  }
  _ = try await client.get(.auth)
  _ = try await client.post(.authLogin, body: Data())
  try await client.deleteNoContent(path: "/plans/test", accessToken: "token")
}
