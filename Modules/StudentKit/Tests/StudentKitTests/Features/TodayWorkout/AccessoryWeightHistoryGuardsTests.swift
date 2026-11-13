import CoreModels
import Foundation
import Testing

@testable import StudentKit

struct AccessoryWeightHistoryGuardsTests {
  @Test func coachSavedAndManualValuesWinIncludingExplicitEmpty() {
    let coach = AccessoryWeightHistoryTests.row(weight: 22.5)
    #expect(AccessoryWeightHistory.apply(to: coach, previousWeight: 20).actualWeight == 22.5)
    for weight: Decimal? in [19, nil] {
      var saved = AccessoryWeightHistoryTests.row()
      saved.actualWeight = weight
      saved.loggedSetID = UUID()
      let result = AccessoryWeightHistory.apply(to: saved, previousWeight: 20)
      #expect(result.actualWeight == weight)
      #expect(result.isHistoryWeightPrefill != true)
    }
    var edited = AccessoryWeightHistoryTests.row()
    edited.isHistoryWeightPrefill = false
    #expect(AccessoryWeightHistory.apply(to: edited, previousWeight: 20).actualWeight == nil)
  }

  @Test func doesNotChangeOtherClassificationsOrLoadModes() {
    let main = AccessoryWeightHistoryTests.row(accessory: false)
    #expect(AccessoryWeightHistory.apply(to: main, previousWeight: 20) == main)
    var rows = [TodayWorkoutSetRowDraft]()
    var bodyweight = AccessoryWeightHistoryTests.row()
    bodyweight.prescribed = PrescribedSet(id: UUID(), setIndex: 0, loadMode: .bodyweight, reps: 12)
    rows.append(bodyweight)
    for intensity: PrescribedIntensity in [.percentage(70), .weightRange(20, 25)] {
      var row = AccessoryWeightHistoryTests.row()
      row.prescribed = PrescribedSet(id: UUID(), setIndex: 0, intensity: intensity, reps: 12)
      rows.append(row)
    }
    var extra = AccessoryWeightHistoryTests.row()
    extra.isExtra = true
    rows.append(extra)
    var added = AccessoryWeightHistoryTests.row()
    added.studentAddedDayID = UUID()
    rows.append(added)
    for row in rows {
      #expect(AccessoryWeightHistory.apply(to: row, previousWeight: 20) == row)
    }
  }

  @Test func absentInvalidAndZeroHistoryAreDistinct() {
    for value: Decimal? in [nil, -1, .nan] {
      let row = AccessoryWeightHistory.apply(
        to: AccessoryWeightHistoryTests.row(), previousWeight: value)
      #expect(row.actualWeight == nil)
      #expect(row.previousAccessoryWeight == nil)
      #expect(row.isHistoryWeightPrefill != true)
    }
    let zero = AccessoryWeightHistory.apply(
      to: AccessoryWeightHistoryTests.row(), previousWeight: 0)
    #expect(zero.actualWeight == 0)
    #expect(zero.isHistoryWeightPrefill == true)
  }

  @Test func oldCachedDraftWithoutMetadataStillDecodes() throws {
    let original = AccessoryWeightHistoryTests.row(weight: 19)
    let encoded = try JSONEncoder().encode(original)
    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object.removeValue(forKey: "previousAccessoryWeight")
    object.removeValue(forKey: "isHistoryWeightPrefill")
    let oldCache = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(TodayWorkoutSetRowDraft.self, from: oldCache)
    #expect(decoded == original)
  }
}
