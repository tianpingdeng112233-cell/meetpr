import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@Suite("Coach day detail set numbers")
struct CoachDayDetailSetNumberTests {
  @Test("planned first set log renders hash one")
  func plannedFirstSetLogRendersHashOne() throws {
    let planDay = try #require(
      CoachStudentFeatureFixtures.plan().days.first { !$0.exercises.isEmpty }
    )
    let day = StudentExecutionDay(
      date: planDay.date,
      planDay: planDay,
      logs: [
        CoachStudentFeatureFixtures.log(
          loggedAt: planDay.date.addingTimeInterval(3_600)
        )
      ]
    )

    let inspected = try CoachDayDetailView(day: day).inspect()

    #expect(try inspected.find(text: "#1").string() == "#1")
  }

  @Test("free first set log renders hash one")
  func freeFirstSetLogRendersHashOne() throws {
    let log = CoachStudentFeatureFixtures.log()
    let day = StudentExecutionDay(
      date: log.loggedAt,
      planDay: nil,
      logs: [log]
    )

    let inspected = try CoachDayDetailView(day: day).inspect()

    #expect(try inspected.find(text: "#1").string() == "#1")
  }
}
