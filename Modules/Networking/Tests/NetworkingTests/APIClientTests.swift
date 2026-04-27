import Testing

@testable import Networking

@Test func sharedClientHasDefaultBaseURL() {
  #expect(APIClient.shared.baseURL.host() == "api.meetpr.local")
}

@Test func endpointsExposeExpectedPaths() {
  #expect(Endpoint.auth.path == "/auth")
  #expect(Endpoint.coach.path == "/coach")
  #expect(Endpoint.student.path == "/student")
}
