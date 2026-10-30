import Foundation
import Testing

@testable import Networking

@Test func minimumVersionUsesBuildNumberAndConfiguredDistributionURL() {
  let info: [String: Any] = [
    "CFBundleVersion": "28", "CFBundleShortVersionString": "1.0",
    "MeetPRUpdateURL": "https://testflight.apple.com/join/example",
  ]
  #expect(BuildConfig.buildNumber(infoDictionary: info) == 28)
  #expect(BuildConfig.buildNumber(infoDictionary: nil) == nil)
  #expect(BuildConfig.updateURL(infoDictionary: info)?.host == "testflight.apple.com")
  #expect(BuildConfig.updateURL(infoDictionary: ["MeetPRUpdateURL": ""]) == nil)
}

@Test(arguments: [0, 27, 28, 29, 100])
func minimumVersionBlocksOnlyOlderBuilds(minimum: Int) async {
  let api = APIClient(transport: { request in
    #expect(request.httpMethod == "GET")
    #expect(request.url?.path == "/app/min-version")
    #expect(request.url?.query == "platform=ios")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(request.timeoutInterval <= 10)
    return APIResponse(data: Data("{\"min_build\":\(minimum)}".utf8), statusCode: 200)
  })
  let required = await api.requiredAppUpdate(currentBuild: 28)
  #expect(required == (minimum > 28 ? minimum : nil))
}

@Test(arguments: ["timeout", "http", "malformed", "negative"])
func minimumVersionFailureAllowsLaunch(failure: String) async {
  let api = APIClient(transport: { _ in
    if failure == "timeout" { throw URLError(.timedOut) }
    return APIResponse(
      data: Data((failure == "negative" ? "{\"min_build\":-1}" : "{}").utf8),
      statusCode: failure == "http" ? 503 : 200)
  })
  #expect(await api.requiredAppUpdate(currentBuild: 28) == nil)
}
