import Foundation
import Testing

@testable import Networking

@Test func deviceTokenEndpointUsesBackendContract() async throws {
  let requestLog = DeviceTokenRequestLog()
  let responseID = try #require(
    UUID(uuidString: "00000000-0000-4000-8000-000000000057"))
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await requestLog.record(request)
    let data = Data(#"{"id":"00000000-0000-4000-8000-000000000057"}"#.utf8)
    return APIResponse(data: data, statusCode: 201)
  }

  let response = try await client.registerDeviceToken("00abff", accessToken: "access-token")

  #expect(response.id == responseID)
  let request = try #require(await requestLog.request())
  #expect(request.httpMethod == "POST")
  #expect(request.url?.path() == "/devices/token")
  #expect(request.value(forHTTPHeaderField: "authorization") == "Bearer access-token")
  let body = try #require(request.httpBody)
  let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
  #expect(json == ["token": "00abff", "platform": "ios"])
}

private actor DeviceTokenRequestLog {
  private var capturedRequest: URLRequest?

  func record(_ request: URLRequest) {
    capturedRequest = request
  }

  func request() -> URLRequest? {
    capturedRequest
  }
}
