import CoreModels
import Foundation
import Testing

@testable import StudentKit

struct AllDaySummaryTests {
  static func rows(_ sets: [PrescribedSet]) -> [TodayWorkoutSetRowDraft] {
    let slot = UUID()
    return sets.map {
      TodayWorkoutSetRowDraft(
        id: $0.id, planExerciseID: slot, exerciseID: slot, exerciseName: "Squat",
        isAccessory: false, prescribed: $0, actualWeight: $0.weightKg,
        actualReps: $0.reps, actualRPE: $0.rpe)
    }
  }

  static func sets(
    _ count: Int, reps: Int = 5, weight: Decimal? = nil,
    intensity: PrescribedIntensity? = nil, load: PlanLoadMode? = nil,
    repsMax: Int? = nil, anchor: PercentageAnchor? = nil
  ) -> [PrescribedSet] {
    (0..<count).map {
      PrescribedSet(
        id: UUID(), setIndex: $0, weightKg: weight, intensity: intensity,
        percentageAnchor: anchor, loadMode: load, reps: reps, repsMax: repsMax)
    }
  }

  @Test func uniformWeight() {
    let result = AllDayExerciseSummary.build(rows: Self.rows(Self.sets(4, reps: 8, weight: 130)))
    #expect(result.segments.map(\.reps) == ["4×8"])
    #expect(result.segments.map(\.load) == ["130"])
    #expect(result.segments.first?.intensityOnly == false)
  }
}

extension AllDaySummaryTests {
  @Test func perSetWeightsAndRepSegments() {
    let weights = Self.sets(2, reps: 3, weight: 135) + Self.sets(1, reps: 3, weight: 120)
    let result = AllDayExerciseSummary.build(rows: Self.rows(weights))
    #expect(result.segments.map(\.reps) == ["3×3"])
    #expect(result.segments.map(\.load) == ["135×2 / 120"])
    let mixed = AllDayExerciseSummary.build(
      rows: Self.rows(
        Self.sets(1, reps: 1, weight: 150) + Self.sets(3, reps: 3, weight: 135)))
    #expect(mixed.segments.map(\.reps) == ["1×1", "3×3"])
    #expect(mixed.segments.map(\.load) == ["150", "135"])
  }

  @Test func actualValuesAndShortRepsUseStyleMarkersAndPreferredUnits() {
    var rows = Self.rows(Self.sets(4, reps: 6, weight: 100))
    rows[0].actualWeight = 90
    rows[0].actualReps = 4
    rows[0].loggedSetID = UUID()
    let result = AllDayExerciseSummary.build(rows: rows)
    #expect(result.segments.map(\.reps) == ["1×4/6", "3×6"])
    #expect(result.segments.map(\.load) == ["90", "100"])
    #expect(result.segments[0].shortReps)
    #expect(result.segments[0].repsChanged)
    #expect(result.segments[0].loadChanged)
    #expect(AllDayExerciseSummary.build(rows: rows, unit: .lb).segments[0].load == "198.4")
    rows[0].actualWeight = nil
    #expect(AllDayExerciseSummary.build(rows: rows).segments[0].load == "—")
  }
}

extension AllDaySummaryTests {
  struct PrescriptionCase: Sendable {
    let sets: [PrescribedSet]
    let reps: String
    let load: String
    let effort: String
    init(_ sets: [PrescribedSet], _ reps: String, _ load: String, _ effort: String = "RPE —") {
      self.sets = sets
      self.reps = reps
      self.load = load
      self.effort = effort
    }
  }
  static let prescriptionCases: [PrescriptionCase] = [
    .init(Self.sets(4, intensity: .weightRange(100, 110)), "4×5", "100–110"),
    .init(Self.sets(3, reps: 8, weight: 60, repsMax: 10), "3×8–10", "60"),
    .init(Self.sets(3, reps: 10, load: .bodyweight), "3×10", "自重"),
    .init(Self.sets(3, reps: 8, weight: 10, load: .bodyweight), "3×8", "自重+10"),
    .init(Self.sets(4, reps: 12, intensity: .rpe(8), load: .freeWeight), "4×12", "自选", "RPE 8"),
    .init(Self.sets(3, intensity: .rpe(8)), "3×5", "—", "RPE 8"),
    .init(Self.sets(3, intensity: .rpeRange(7, 8)), "3×5", "—", "RPE 7–8"),
    .init(Self.sets(3, reps: 10, intensity: .rir(2)), "3×10", "—", "RIR 2"),
    .init(Self.sets(4, weight: 100, intensity: .rpe(7)), "4×5", "100", "RPE 7"),
    .init(Self.sets(5, intensity: .percentage(75)), "5×5", "75%"),
    .init(Self.sets(3, intensity: .percentage(60), anchor: .topSet), "3×5", "60% 顶组"),
  ]
  @Test(arguments: prescriptionCases)
  func rangesBodyweightAndEffortPrescriptions(sample: PrescriptionCase) {
    let result = AllDayExerciseSummary.build(
      rows: Self.rows(sample.sets), locale: Locale(identifier: "zh-Hans"))
    #expect(result.segments.map(\.reps) == [sample.reps])
    #expect(result.segments.map(\.load) == [sample.load])
    #expect(result.segments.map(\.effort) == [sample.effort])
  }

  @Test func varyingRPEKeepsCoachWordsAndHidesSuggestedWeightsUntilRecorded() {
    let sets = [6, 7, 8, 8].flatMap { Self.sets(1, reps: 12, intensity: .rpe(Decimal($0))) }
    var rows = Self.rows(sets)
    for index in rows.indices { rows[index].actualWeight = 60 }
    let result = AllDayExerciseSummary.build(rows: rows)
    #expect(result.segments.map(\.load) == ["—"])
    #expect(result.segments.map(\.effort) == ["RPE 6/7/8/8"])
    #expect(result.segments[0].intensityOnly)
    let weighted = [6, 7, 8, 8].flatMap {
      Self.sets(1, reps: 12, weight: 100, intensity: .rpe(Decimal($0)))
    }
    #expect(AllDayExerciseSummary.build(rows: Self.rows(weighted)).segments.map(\.load) == ["100"])
    for index in rows.indices { rows[index].loggedSetID = UUID() }
    #expect(AllDayExerciseSummary.build(rows: rows).segments.map(\.load) == ["60"])
  }

  @Test func resolvedPercentageAndEmptyAddedExercise() {
    var rows = Self.rows(Self.sets(5, intensity: .percentage(75)))
    for index in rows.indices { rows[index].actualWeight = 112.5 }
    #expect(AllDayExerciseSummary.build(rows: rows).segments.map(\.load) == ["112.5"])
    rows = Self.rows(Self.sets(3, intensity: .percentage(60), anchor: .topSet))
    for index in rows.indices { rows[index].actualWeight = 90 }
    #expect(AllDayExerciseSummary.build(rows: rows).segments.map(\.load) == ["90"])
    rows = Self.rows(Self.sets(1))
    rows[0].studentAddedDayID = UUID()
    rows[0].actualReps = nil
    #expect(
      AllDayExerciseSummary.build(rows: rows, locale: Locale(identifier: "zh-Hans")).segments.map(
        \.load) == ["未记录"])
    rows[0].actualWeight = 50
    rows[0].actualReps = 8
    #expect(AllDayExerciseSummary.build(rows: rows).segments.map(\.reps) == ["1×8"])
    #expect(AllDayExerciseSummary.build(rows: rows).segments.map(\.load) == ["50"])
  }
}

extension AllDaySummaryTests {
  @Test func allDayKeypadUsesPreferredUnit() {
    let row = Self.rows(Self.sets(1, weight: 100))[0]
    let cells = WorkoutKeypadCell.allDayCells(draft: row, unit: .lb)
    #expect(cells[0].value == "220.5")
    #expect(cells[0].unit == "lb")
  }

  @Test func oldPrescriptionCacheStillDecodesAfterAMRAPProjection() throws {
    let set = Self.sets(1, weight: 100)[0]
    var object = try #require(
      JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(set)) as? [String: Any])
    object.removeValue(forKey: "set_type")
    let restored = try MeetPRCodec.decoder.decode(
      PrescribedSet.self,
      from: JSONSerialization.data(withJSONObject: object))
    #expect(restored.setType == .working)
    #expect(restored.weightKg == 100)
    #expect(restored.id == set.id)
  }
}

@Test func fixedColumnsReserveMissingWeightForRPE() {
  let result = AllDayExerciseSummary.build(
    rows: AllDaySummaryTests.rows(AllDaySummaryTests.sets(3, intensity: .rpe(8))))
  #expect(result.segments.map(\.load) == ["—"])
  #expect(result.segments.map(\.effort) == ["RPE 8"])
}

extension AllDaySummaryTests {
  @Test func sameRepsStayInOneSegmentAfterRecordingOneWeight() {
    var rows = Self.rows(Self.sets(4, reps: 5, weight: 100))
    rows[0].actualWeight = 90
    rows[0].loggedSetID = UUID()
    let result = AllDayExerciseSummary.build(rows: rows)
    #expect(result.segments.map(\.reps) == ["4×5"])
    #expect(result.segments.map(\.load) == ["90 / 100×3"])
    #expect(result.segments.first?.weightChanged == true)
  }
}

extension AllDaySummaryTests {
  @Test func recordedWeightedSetsKeepEveryRPEInTheSummary() {
    var rows = Self.rows(Self.sets(4, reps: 7, weight: 100))
    for (index, value) in [6, 7, 8, 8].enumerated() {
      rows[index].actualWeight = [95, 100, 105, 110][index]
      rows[index].actualRPE = Decimal(value)
      rows[index].loggedSetID = UUID()
    }
    let result = AllDayExerciseSummary.build(rows: rows)
    #expect(result.segments.map(\.reps) == ["4×7"])
    #expect(result.segments.map(\.load) == ["95 / 100 / 105 / 110"])
    #expect(result.segments.map(\.effort) == ["RPE 6/7/8/8"])
    rows[1].actualRPE = nil
    #expect(AllDayExerciseSummary.build(rows: rows).segments.map(\.effort) == ["RPE 6/—/8/8"])
    for (index, value) in [3, 2, 1, 1].enumerated() {
      rows[index].actualRPE = nil
      rows[index].actualRIR = value
    }
    #expect(AllDayExerciseSummary.build(rows: rows).segments.map(\.effort) == ["RIR 3/2/1/1"])
  }
}

extension AllDaySummaryTests {
  @Test func emptyRecordedEffortKeepsCoachTypeWithoutRestoringTarget() {
    var rows = Self.rows(Self.sets(2, weight: 100, intensity: .rir(2)))
    for index in rows.indices { rows[index].loggedSetID = UUID() }
    #expect(AllDayExerciseSummary.build(rows: rows).segments.map(\.effort) == ["RIR —"])
    rows[0].actualRPE = 8
    #expect(AllDayExerciseSummary.build(rows: rows).segments.map(\.effort) == ["RPE 8 / RIR —"])
  }
}

extension AllDaySummaryTests {
  @Test func emptyEffortUsesRememberedTypeAfterCoachAndNeverRelabelsActuals() {
    var rows = Self.rows(Self.sets(2, weight: 100))
    #expect(
      AllDayExerciseSummary.build(rows: rows, previousEffort: .rir).segments[0].effort == "RIR —")
    rows[0].prescribed = PrescribedSet(
      id: rows[0].id, setIndex: 0, weightKg: 100, intensity: .rpe(7), reps: 5)
    rows[0].loggedSetID = UUID()
    #expect(
      AllDayExerciseSummary.build(rows: rows, previousEffort: .rir).segments[0].effort
        == "RPE — / RIR —")
    rows[0].actualRPE = 8
    #expect(
      AllDayExerciseSummary.build(rows: rows, previousEffort: .rir).segments[0].effort
        == "RPE 8 / RIR —")
  }
}
