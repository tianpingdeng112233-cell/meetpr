import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func failedPrescriptionHidesPlaceholderReps() throws {
  let payload = """
    {"id":"00000000-0000-0000-0000-000000000001","set_index":0,
     "weight_kg":"100","reps":1,"set_type":"failed"}
    """
  let set = try MeetPRCodec.decoder.decode(PrescribedSet.self, from: Data(payload.utf8))
  #expect(StudentFormatting.prescribed(set, locale: Locale(identifier: "zh-Hans")) == "100kg x 力竭")
  #expect(
    StudentFormatting.prescribed(set, locale: Locale(identifier: "en")) == "100kg x to failure")
  #expect(StudentFormatting.prescribed(set, locale: Locale(identifier: "zh-Hant")) == "100kg x 力竭")
}

@Test(arguments: [
  (PlanLoadMode.fixedWeight, PrescribedIntensity?.none, "100kg × to failure"),
  (.percentage, .percentage(70), "100kg × to failure @70%"),
  (.rpeRange, .rpeRange(8, 9), "100kg × to failure @RPE8–9"),
  (.weightRange, .weightRange(80, 90), "80–90kg × to failure"),
])
func failedNewFormPrescriptionHidesBothRepBounds(
  mode: PlanLoadMode, intensity: PrescribedIntensity?, expected: String
) {
  let set = PrescribedSet(
    id: UUID(), setIndex: 0, weightKg: 100, intensity: intensity,
    loadMode: mode, reps: 1, repsMax: 12, setType: .failed)
  #expect(StudentFormatting.prescribed(set, locale: Locale(identifier: "en")) == expected)
  #expect(StudentFormatting.result(weightKg: 100, reps: 12, rpe: 9) == "100kg × 12 @ RPE 9")
}
