import Foundation
import Testing

@testable import Networking

@Test func accountEndpointsSendAuthenticatedRequests() async throws {
  let capture = AccountRequestCapture()
  let client = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await capture.record(request)
    return APIResponse(data: Data(), statusCode: 204)
  }

  try await client.deleteAccount(accessToken: "access-token")
  try await client.changePassword(
    ChangePasswordRequestDTO(oldPassword: "old-pass-1", newPassword: "new-pass-2"),
    accessToken: "access-token"
  )

  let requests = await capture.requests()
  #expect(requests.count == 2)
  #expect(requests[0].url?.path() == "/me")
  #expect(requests[0].httpMethod == "DELETE")
  #expect(requests[0].value(forHTTPHeaderField: "authorization") == "Bearer access-token")

  #expect(requests[1].url?.path() == "/me/password")
  #expect(requests[1].httpMethod == "PUT")
  #expect(requests[1].value(forHTTPHeaderField: "authorization") == "Bearer access-token")
  #expect(requests[1].value(forHTTPHeaderField: "content-type") == "application/json")
  let body = try #require(requests[1].httpBody)
  let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
  #expect(object == ["old_password": "old-pass-1", "new_password": "new-pass-2"])
}

private actor AccountRequestCapture {
  private var capturedRequests: [URLRequest] = []

  func record(_ request: URLRequest) {
    capturedRequests.append(request)
  }

  func requests() -> [URLRequest] {
    capturedRequests
  }
}
