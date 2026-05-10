import Foundation
import Testing

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
@Test func progressionRuleTypeRawValuesStaySnakeCase() {
  #expect(ProgressionRuleType.weightInc.rawValue == "weight_inc")
  #expect(ProgressionRuleType.weightDec.rawValue == "weight_dec")
  #expect(ProgressionRuleType.rpeInc.rawValue == "rpe_inc")
  #expect(ProgressionRuleType.rpeDec.rawValue == "rpe_dec")
  #expect(ProgressionRuleType.setsInc.rawValue == "sets_inc")
  #expect(ProgressionRuleType.setsDec.rawValue == "sets_dec")
  #expect(ProgressionRuleType.repsInc.rawValue == "reps_inc")
  #expect(ProgressionRuleType.repsDec.rawValue == "reps_dec")
  #expect(ProgressionRuleType.custom.rawValue == "custom")
}

@available(iOS 17.0, macOS 14.0, *)
@Test func draftProgressionRuleEncodesDecimalAsString() throws {
  let rule = Spec007Fixtures.rule(.rpeInc, increment: 0.5)

  let data = try encodeRules([rule])
  let json = try #require(String(data: data, encoding: .utf8))

  #expect(json.localizedStandardContains("\"0.5\""))
}

@available(iOS 17.0, macOS 14.0, *)
@Test func customProgressionRuleRoundTripsSequenceAndDimension() throws {
  let rule = Spec007Fixtures.rule(
    .custom,
    increment: nil,
    sequence: [105, 110, 115],
    dimension: .weight,
    weeks: [2, 3, 4]
  )

  let decoded = decodeRules(try encodeRules([rule]))

  #expect(decoded.first?.customDimension == .weight)
  #expect(decoded.first?.customSequence == [105, 110, 115])
}

@available(iOS 17.0, macOS 14.0, *)
@Test func draftProgressionRulePreservesExerciseIDSet() throws {
  let rule = Spec007Fixtures.rule(
    .weightInc,
    exerciseID: PlanningFixtures.uuid(201)
  )

  let decoded = decodeRules(try encodeRules([rule]))

  #expect(decoded.first?.exerciseIDs == [PlanningFixtures.uuid(201)])
}
