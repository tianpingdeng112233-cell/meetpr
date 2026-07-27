import Foundation
import NetworkingTestSupport
import Testing

@testable import Networking

@Test func stubHTTPHarnessDrivesAPIClientSuccessAndErrorPaths() async throws {
  let harness = StubHTTPHarness()
  let client = APIClient(
    environment: ["MEETPR_API_BASE_URL": "https://api.test"],
    transport: harness.transport
  )

  harness.enqueue(
    body: Data(
      #"{"gym_day":"2026-07-17","session":null}"#.utf8
    )
  )

  let response = try await client.studentSession(date: "2026-07-17", accessToken: "token")
  #expect(response.gymDay == "2026-07-17")
  #expect(response.session == nil)

  let errorBody = Data(#"{"error":"temporarily_unavailable"}"#.utf8)
  harness.enqueue(statusCode: 503, body: errorBody)

  do {
    _ = try await client.studentSession(accessToken: "token")
    Issue.record("Expected the API client to reject a non-2xx response.")
  } catch let error as APIError {
    #expect(error == .httpStatus(503, errorBody))
  }
}
