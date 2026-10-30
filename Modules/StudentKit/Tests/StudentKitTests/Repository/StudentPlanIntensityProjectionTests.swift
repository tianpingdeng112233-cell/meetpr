import ChatUI
import CoreModels
import Foundation
import Networking
import Testing
import ViewInspector

@testable import StudentKit

@Test(arguments: ["自重", "自重 慢下放", "BODYWEIGHT"])
func legacyMarkerBodyweightProjectionIgnoresCompatibilityRPE(note: String) throws {
  let plan = loadTypeProjection(mode: nil, coachNote: note)
  let set = try #require(plan.days.first?.exercises.first?.prescribedSets.first)
  #expect(set.isBodyweight)
  #expect(set.weightKg == nil)
  #expect(set.intensity == nil)
  #expect(set.rpe == nil)
  #expect(StudentFormatting.prescribed(set) == "自重 × 5")
  #expect(set.visibleCoachNote == (note == "自重 慢下放" ? "慢下放" : nil))
}

@MainActor
@Test(arguments: [IntensityMode.weight, .rpe], [nil, "自重", "自重 慢下放", "BODYWEIGHT"])
func legacyRealPrescriptionKeepsLoadAndNote(mode: IntensityMode, note: String?) throws {
  let view = loadTypeProjection(
    mode: nil, coachNote: note, legacyMode: mode, legacyValue: mode == .weight ? 135 : 8)
  let set = try #require(view.days.first?.exercises.first?.prescribedSets.first)
  #expect(!set.isBodyweight)
  #expect(set.weightKg == (mode == .weight ? 135 : nil))
  #expect(set.intensity == (mode == .rpe ? .rpe(8) : nil))
  #expect(set.visibleCoachNote == note)
  let day = try #require(view.days.first)
  let drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
  let row = AccessoryRow(draft: drafts[0], previous: nil, unit: .kg)
  if mode == .rpe { #expect(row.rpePlaceholder == "8") }
}

@MainActor
@Test func legacyMarkerBodyweightJSONDecodesAndProjectsWithoutRPE10() throws {
  let fixture = intensityProjectionFixture()
  let json = """
    {
      "id": "90000000-0000-0000-0000-000000000001",
      "plan_exercise_id": "\(fixture.tree.exercises[0].id)",
      "set_number": 1,
      "target_reps": 0,
      "load_mode": null,
      "intensity_mode": "rpe",
      "target_value": "10.00",
      "coach_note": "自重",
      "set_type": "working",
      "created_at": "2026-10-30T00:00:00Z"
    }
    """
  let decoded = try MeetPRCodec.decoder.decode(PlanSetDTO.self, from: Data(json.utf8)).toDomain()
  #expect(decoded.loadMode == nil)
  #expect(decoded.intensityMode == .rpe)
  #expect(decoded.targetValue == 10)
  let plan = StudentPlanProjection.project(
    tree: TrainingPlanTree(
      plan: fixture.tree.plan, days: fixture.tree.days,
      exercises: fixture.tree.exercises, sets: [decoded]),
    catalog: [fixture.catalogExercise], weekIndex: 1)
  let set = try #require(plan.days.first?.exercises.first?.prescribedSets.first)
  #expect(set.isBodyweight)
  #expect(set.weightKg == nil)
  #expect(set.intensity == nil)
  #expect(set.rpe == nil)
  #expect(set.visibleCoachNote == nil)
  let header = LoadTypePrescriptionHeader(set: set, count: 3)
  #expect(try header.inspect().find(text: "3 × 力竭").string() == "3 × 力竭")
}

@MainActor
@Test(arguments: [PlanLoadMode?.none, .bodyweight, .freeWeight], [nil, Decimal(8)])
func loadTypeLegacyProjectionDoesNotInventIntensity(
  mode: PlanLoadMode?, targetRPE: Decimal?
) throws {
  let plan = loadTypeProjection(
    mode: mode, targetRPE: targetRPE, coachNote: mode == nil ? "自重" : nil)
  let day = try #require(plan.days.first)
  let set = try #require(day.exercises.first?.prescribedSets.first)
  let drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
  let draft = try #require(drafts.first)
  let label = mode == .freeWeight ? "自选重量" : "自重"
  let expected = targetRPE == nil ? "\(label) × 5" : "\(label) × 5 · RPE 8"
  #expect(StudentFormatting.prescribed(set) == expected)
  #expect(HistorySetRow(set: set, log: nil).result == expected)
  let header = LoadTypePrescriptionHeader(set: set, count: 1)
  let summary = targetRPE == nil ? "1 × 5" : "1 × 5 · 目标 RPE 8"
  #expect(try header.inspect().find(text: summary).string() == summary)
  let presentation = TodayWorkoutPresentation(
    day: day, drafts: drafts, references: [:], started: true)
  #expect(presentation.exercises.first?.prescriptionSummary == "\(expected) · 1 组")
  #expect(presentation.currentRow?.record.rpe == (targetRPE == nil ? 0 : 8))
  #expect(draft.actualRPE == targetRPE)
  let row = AccessoryRow(draft: draft, previous: nil, unit: .kg)
  #expect(row.input.rpe.isEmpty)
  #expect(row.rpePlaceholder == (targetRPE == nil ? "" : "8"))
}

private func loadTypeProjection(
  mode: PlanLoadMode?, targetRPE: Decimal? = nil,
  rpeLow: Decimal? = nil, rpeHigh: Decimal? = nil,
  rirTarget: Int? = nil, targetPct: Decimal? = nil,
  coachNote: String? = nil, legacyMode: IntensityMode = .rpe, legacyValue: Decimal = 10
) -> StudentPlanView {
  let fixture = intensityProjectionFixture()
  let set = intensityProjectionSet(
    exerciseID: fixture.tree.sets[0].planExerciseID, timestamp: .distantPast, number: 1,
    legacyMode: legacyMode, legacyValue: legacyValue, loadMode: mode, targetPct: targetPct,
    targetRPE: targetRPE, rirTarget: rirTarget,
    rpeLow: rpeLow, rpeHigh: rpeHigh, coachNote: coachNote)
  return StudentPlanProjection.project(
    tree: TrainingPlanTree(
      plan: fixture.tree.plan, days: fixture.tree.days,
      exercises: fixture.tree.exercises, sets: [set]),
    catalog: [fixture.catalogExercise], weekIndex: 1)
}

@MainActor
@Test(arguments: [PlanLoadMode?.none, .bodyweight, .freeWeight])
func loadTypeLegacyProjectionKeepsCanonicalIntensityRange(mode: PlanLoadMode?) throws {
  let plan = loadTypeProjection(
    mode: mode, rpeLow: 7, rpeHigh: 9, coachNote: mode == nil ? "自重" : nil)
  let set = try #require(plan.days.first?.exercises.first?.prescribedSets.first)
  let label = mode == .freeWeight ? "自选重量" : "自重"
  #expect(StudentFormatting.prescribed(set) == "\(label) × 5 · RPE 7–9")
  let header = LoadTypePrescriptionHeader(set: set, count: 1)
  #expect(
    try header.inspect().find(text: "1 × 5 · 目标 RPE 7–9").string()
      == "1 × 5 · 目标 RPE 7–9")
  #expect(set.rpe == nil)
}

@MainActor
@Test(arguments: [PlanLoadMode?.none, .bodyweight, .freeWeight], [nil, Decimal(8)])
func loadTypeLegacyProjectionEntryPreservesOptionalRPE(
  mode: PlanLoadMode?, targetRPE: Decimal?
) async throws {
  let plan = loadTypeProjection(
    mode: mode, targetRPE: targetRPE, coachNote: mode == nil ? "自重" : nil)
  let day = try #require(plan.days.first)
  let studentID = UUID()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan])),
    logs: InMemoryStudentTrainingLogRepository())
  await model.load(dayID: day.id, studentID: studentID)
  model.updateWeight(rowIndex: 0, weight: 20)
  let draft = try #require(model.currentDrafts?.first)
  let sheet = SetEntrySheet(rowIndex: 0, draft: draft, setNumber: 1, viewModel: model)
  try sheet.inspect().find(button: StudentStrings.localized(.setEntrySheet012)).tap()
  #expect(model.currentDrafts?.first?.actualRPE == targetRPE)
}

@Test(arguments: [PlanLoadMode?.none, .bodyweight, .freeWeight], [nil, Decimal(8)])
func loadTypeLegacyProjectionChatUsesOnlyCanonicalRPE(
  mode: PlanLoadMode?, targetRPE: Decimal?
) async throws {
  let plan = loadTypeProjection(
    mode: mode, targetRPE: targetRPE, coachNote: mode == nil ? "自重" : nil)
  let studentID = UUID()
  let source = TodaySetRefSharingSource(
    studentID: studentID,
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan])),
    logs: InMemoryStudentTrainingLogRepository(), videoManager: VideoUploadServices.demo().manager)
  let candidate = try #require(try await source.loadCandidates().first)
  #expect(candidate.source.rpe == (targetRPE == nil ? nil : "8"))
  let reference = try SetRefV1.normalizingSource(candidate.source)
  let line = ChatSetRefDisplayFormatter.firstLine(for: reference)
  #expect(!line.contains("RPE 10"))
  #expect(line.contains("RPE") == (targetRPE != nil))
}

@Test(arguments: [PlanLoadMode?.none, .bodyweight, .freeWeight])
func loadTypeLegacyProjectionKeepsRIRPercentageAndIncompleteRange(mode: PlanLoadMode?) throws {
  let note = mode == nil ? "自重" : nil
  let plans = [
    loadTypeProjection(mode: mode, rirTarget: 2, coachNote: note),
    loadTypeProjection(mode: mode, targetPct: 75, coachNote: note),
    loadTypeProjection(mode: mode, rpeLow: 7, coachNote: note),
  ]
  let label = mode == .freeWeight ? "自选重量" : "自重"
  let expected = ["\(label) × 5 · RIR 2", "\(label) × 5 · 75%", "\(label) × 5"]
  for (plan, text) in zip(plans, expected) {
    let set = try #require(plan.days.first?.exercises.first?.prescribedSets.first)
    #expect(StudentFormatting.prescribed(set) == text)
    #expect(set.rpe == nil)
  }
}

@Test func studentProjectionUsesCanonicalIntensityFieldsAndIgnoresLegacyProjection() throws {
  let fixture = intensityProjectionFixture()

  let view = StudentPlanProjection.project(
    tree: fixture.tree,
    catalog: [fixture.catalogExercise],
    weekIndex: 1
  )
  let sets = try #require(view.days.first?.exercises.first?.prescribedSets)

  #expect(sets.count == 10)
  #expect(sets[0].weightKg == nil)
  #expect(sets[0].intensity == .percentage(72.5))
  #expect(sets[0].percentageAnchor == .e1RM)
  #expect(sets[0].rpe == nil)
  #expect(sets[0].restSeconds == 180)
  #expect(sets[1].intensity == .rpe(8.5))
  #expect(sets[2].intensity == .rir(2))
  #expect(sets[3].intensity == .weightRange(165, 175))
  #expect(sets[4].intensity == .rpeRange(9, 9.5))
  #expect(sets[4].restSeconds == 240)
  #expect(sets[5].weightKg == 170)
  #expect(sets[5].intensity == nil)
  #expect(sets[5].restSeconds == 180)
  #expect(sets[6].weightKg == 170)
  #expect(sets[6].intensity == .rpe(9))
  #expect(sets[7].weightKg == 150)
  #expect(sets[7].intensity == nil)
  #expect(sets[8].weightKg == nil)
  #expect(sets[8].intensity == .rpe(8))
  #expect(sets[8].restSeconds == nil)
  #expect(sets[9].weightKg == 140)
  #expect(sets[9].intensity == nil)
  #expect(sets[0].loadMode == .percentage)
  #expect(sets[7].loadMode == .percentage)
  #expect(!sets[7].isLegacyPrescription)
  #expect(sets[8].isLegacyPrescription)
  #expect(sets[9].isLegacyPrescription)
}

@Test func scheduledDateKeepsLegacyStartDateWhenAnchorIsNil() {
  let startDate = utcDate(year: 2026, month: 8, day: 14)
  let day = projectionDay(week: 1, dayOfWeek: 1)

  let scheduled = StudentPlanProjection.scheduledDate(
    for: day,
    startDate: startDate,
    anchorWeekday: nil
  )

  #expect(scheduled == startDate)
}

@Test func scheduledDateIncludesStartDateWhenItMatchesAnchor() {
  let wednesday = utcDate(year: 2026, month: 8, day: 12)
  let day = projectionDay(week: 1, dayOfWeek: 1)

  let scheduled = StudentPlanProjection.scheduledDate(
    for: day,
    startDate: wednesday,
    anchorWeekday: 3
  )

  #expect(scheduled == wednesday)
}

@Test func scheduledDateMovesToNextAnchorAndAppliesCrossWeekOffset() {
  let friday = utcDate(year: 2026, month: 8, day: 14)
  let weekTwoDayThree = projectionDay(week: 2, dayOfWeek: 3)

  let scheduled = StudentPlanProjection.scheduledDate(
    for: weekTwoDayThree,
    startDate: friday,
    anchorWeekday: 1
  )

  #expect(scheduled == utcDate(year: 2026, month: 8, day: 26))
}

private func intensityProjectionFixture() -> (
  tree: TrainingPlanTree, catalogExercise: Exercise
) {
  let timestamp = utcDate(year: 2026, month: 8, day: 12)
  let planID = UUID()
  let dayID = UUID()
  let planExerciseID = UUID()
  let catalogID = UUID()
  let plan = projectionPlan(id: planID, timestamp: timestamp)
  let day = PlanDay(
    id: dayID, planID: planID, dayOfWeek: 1, weekNumber: 1, sortOrder: 0)
  let exercise = PlanExercise(
    id: planExerciseID,
    planDayID: dayID,
    exerciseID: catalogID,
    isMainLift: true,
    sortOrder: 0
  )
  let sets = intensityProjectionSets(planExerciseID: planExerciseID, timestamp: timestamp)
  let catalogExercise = projectionCatalogExercise(id: catalogID, timestamp: timestamp)
  return (
    TrainingPlanTree(plan: plan, days: [day], exercises: [exercise], sets: sets),
    catalogExercise
  )
}

private func projectionPlan(id: UUID, timestamp: Date) -> TrainingPlan {
  TrainingPlan(
    id: id,
    traineeID: UUID(),
    name: "六形式",
    startDate: timestamp,
    endDate: timestamp.addingTimeInterval(2_419_200),
    planWeeks: 4,
    source: .coach,
    status: .published,
    createdAt: timestamp,
    updatedAt: timestamp
  )
}

private func projectionCatalogExercise(id: UUID, timestamp: Date) -> Exercise {
  Exercise(
    id: id,
    name: "深蹲",
    exerciseType: .mainLift,
    isCompetitionLift: true,
    muscleGroups: [.quad],
    equipment: [.barbell],
    createdAt: timestamp
  )
}

private func projectionDay(week: Int, dayOfWeek: Int) -> PlanDay {
  PlanDay(
    id: UUID(),
    planID: UUID(),
    dayOfWeek: dayOfWeek,
    weekNumber: week,
    sortOrder: 0
  )
}

private func utcDate(year: Int, month: Int, day: Int) -> Date {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
  return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
}

@Test func accessoryProjectionDoesNotInventCoachRestFromMainLiftRules() throws {
  let fixture = intensityProjectionFixture()
  let catalog = Exercise(
    id: fixture.catalogExercise.id, name: "Row", exerciseType: .accessory,
    isCompetitionLift: false, muscleGroups: [], equipment: [], createdAt: .distantPast)
  let projected = StudentPlanProjection.project(
    tree: fixture.tree, catalog: [catalog], weekIndex: 1)
  let sets = try #require(projected.days.first?.exercises.first?.prescribedSets)
  #expect(sets.allSatisfy { $0.restSeconds == nil })
}

@Test func accessoryProjectionPreservesCoachRestAndMainLiftVariants() throws {
  let fixture = intensityProjectionFixture()
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()
  var object = try #require(
    JSONSerialization.jsonObject(with: encoder.encode(fixture.tree.sets[0])) as? [String: Any])
  object["restSeconds"] = 75
  let explicit = try decoder.decode(
    PlanSet.self, from: JSONSerialization.data(withJSONObject: object))
  let tree = TrainingPlanTree(
    plan: fixture.tree.plan, days: fixture.tree.days, exercises: fixture.tree.exercises,
    sets: [explicit] + fixture.tree.sets.dropFirst())
  func sets(_ type: ExerciseType) throws -> [PrescribedSet] {
    let catalog = Exercise(
      id: fixture.catalogExercise.id, name: "Fixture", exerciseType: type,
      isCompetitionLift: false, muscleGroups: [], equipment: [], createdAt: .distantPast)
    return try #require(
      StudentPlanProjection.project(
        tree: tree, catalog: [catalog], weekIndex: 1
      ).days.first?.exercises.first?.prescribedSets)
  }
  let accessory = try sets(.accessory)
  #expect(accessory[0].restSeconds == 75)
  #expect(accessory.dropFirst().allSatisfy { $0.restSeconds == nil })
  let main = try sets(.mainLift)
  let variation = try sets(.mainLiftVariation)
  #expect(main == variation)
  #expect(main.map(\.restSeconds) == [75, 180, 180, 180, 240, 180, 240, 180, nil, nil])
}
