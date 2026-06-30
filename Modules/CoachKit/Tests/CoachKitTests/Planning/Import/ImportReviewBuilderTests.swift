import CoreModels
import Foundation
import Testing

@testable import CoachKit

// spec 043 hardening — a year-long date skeleton (邓天平.xlsx's "2026" sheet has 52
// week headers, only ~14 filled) must not flood review with empty weeks.

@Test func buildDropsWeeksWithoutExercises() {
  let contentWeek = ParsedWeek(
    blockIndex: 0, dateSerials: [],
    days: [
      ParsedDay(
        dayOfWeek: 0,
        exercises: [ParsedExercise(rawName: "深蹲", sets: [ParsedSet(reps: 5, weightKg: 100)])])
    ])
  let emptyWeek = ParsedWeek(
    blockIndex: 1, dateSerials: [],
    days: [ParsedDay(dayOfWeek: 0, exercises: [])])

  let weeks = ImportReviewBuilder.build(
    from: ParsedPlan(weeks: [contentWeek, emptyWeek]), catalog: [])

  #expect(weeks.count == 1)
  #expect(weeks.first?.blockIndex == 0)
}
