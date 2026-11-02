import CoreModels
import Foundation
import Testing

private struct LegacyBodyweightCase: Sendable {
  let weight: Decimal?
  let rpe: Decimal?
  let bodyweight: Bool
}

@Test(arguments: [
  LegacyBodyweightCase(weight: 135, rpe: nil, bodyweight: false),
  LegacyBodyweightCase(weight: 135, rpe: 10, bodyweight: false),
  LegacyBodyweightCase(weight: nil, rpe: 8, bodyweight: false),
  LegacyBodyweightCase(weight: nil, rpe: nil, bodyweight: false),
  LegacyBodyweightCase(weight: nil, rpe: 10, bodyweight: true),
])
private func legacyPrescribedSetRequiresExactBodyweightEncoding(testCase: LegacyBodyweightCase) {
  let set = PrescribedSet(
    id: UUID(), setIndex: 0, weightKg: testCase.weight, reps: 5,
    rpe: testCase.rpe, coachNote: "自重 慢下放")
  #expect(set.isBodyweight == testCase.bodyweight)
  #expect(set.hasUnspecifiedLoad == testCase.bodyweight)
  #expect(set.visibleCoachNote == (testCase.bodyweight ? "慢下放" : "自重 慢下放"))
}
