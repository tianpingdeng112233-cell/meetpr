import Foundation
import Testing

@testable import Networking

@Test func registerDeviceTokenPostsAuthenticatedIOSPayload() async throws {
  let capture = DeviceRequestCapture()
  let responseID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await capture.record(request)
    return APIResponse(
      data: Data(#"{"id":"\#(responseID.uuidString)"}"#.utf8),
      statusCode: 201
    )
  }

  try await client.registerDeviceToken("00abff", accessToken: "access-token")
  let request = try #require(await capture.request())
  let body = try #require(request.httpBody)
  let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])

  #expect(request.url?.absoluteString == "https://api.test/devices/token")
  #expect(request.httpMethod == "POST")
  #expect(request.value(forHTTPHeaderField: "authorization") == "Bearer access-token")
  #expect(json == ["token": "00abff", "platform": "ios"])
}

private actor DeviceRequestCapture {
  private var capturedRequest: URLRequest?

  func record(_ request: URLRequest) {
    capturedRequest = request
  }

  func request() -> URLRequest? {
    capturedRequest
  }
}
