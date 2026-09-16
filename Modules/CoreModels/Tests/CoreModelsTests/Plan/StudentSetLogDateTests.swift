import CoreModels
import Foundation
import Testing

@Suite struct StudentSetLogDateTests {
  @Test func wireTrainingDateUsesGregorianYearWithTheDevicesTimeZone() throws {
    var buddhist = Calendar(identifier: .buddhist)
    buddhist.timeZone = try #require(TimeZone(identifier: "Asia/Bangkok"))
    let serverLoggedAt = try Date("2026-09-02T10:00:00Z", strategy: .iso8601)
    let expectedNoon = try Date("2026-09-01T05:00:00Z", strategy: .iso8601)

    let resolved = StudentSetLog.resolvedLoggedAt(
      serverLoggedAt: serverLoggedAt,
      loggedDate: "2026-09-01",
      calendar: buddhist
    )

    #expect(resolved == expectedNoon)
  }
}
