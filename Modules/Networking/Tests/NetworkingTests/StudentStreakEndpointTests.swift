import Foundation
import Testing

@testable import Networking

@Test("student streak endpoint decodes the authenticated wire contract")
func studentStreakEndpointDecodesWireContract() async throws {
  let requestLog = StudentStreakRequestLog()
  let client = APIClient(
    environment: ["MEETPR_API_BASE_URL": "https://api.test"]
  ) { request in
    await requestLog.record(request)
    return APIResponse(
      data: Data(
        """
        {
          "streak": {
            "current": 12,
            "as_of": "2026-07-25",
            "started_on": "2026-07-01",
            "last_session_date": "2026-07-24"
          }
        }
        """.utf8
      ),
      statusCode: 200
    )
  }

  let response = try await client.studentStreak(accessToken: "student-token")
  let request = try #require(await requestLog.request)

  #expect(request.httpMethod == "GET")
  #expect(request.url?.path() == "/students/me/streak")
  #expect(request.value(forHTTPHeaderField: "authorization") == "Bearer student-token")
  #expect(response.streak?.current == 12)
  #expect(response.streak?.asOf == "2026-07-25")
  #expect(response.streak?.startedOn == "2026-07-01")
  #expect(response.streak?.lastSessionDate == "2026-07-24")
}

private actor StudentStreakRequestLog {
  private(set) var request: URLRequest?

  func record(_ request: URLRequest) {
    self.request = request
  }
}
