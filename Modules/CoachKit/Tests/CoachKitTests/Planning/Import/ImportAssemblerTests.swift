import CoreModels
import Foundation
import Testing

@testable import CoachKit

// spec 043 §F/§H — direct entity-tree assembly + completeness gate.

private let fixedNow = Date(timeIntervalSince1970: 1_777_248_000)  // 2026-04-27 UTC

private func makeID(_ counter: inout Int) -> UUID {
  counter += 1
  return UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(counter)))
}

private func reviewSet(
  _ number: Int, weight: String?, reps: Int? = 3, rpe: String? = nil, note: String? = nil
) -> ImportReviewSet {
  ImportReviewSet(
    id: UUID(),
    setNumber: number,
    targetReps: reps,
    targetRepsMax: nil,
    weightKg: weight.flatMap { Decimal(string: $0) },
    rpe: rpe.flatMap { Decimal(string: $0) },
    setType: .working,
    coachNote: note
  )
}

private func reviewExercise(boundID: UUID? = UUID(), mainLift: Bool = true, sets: [ImportReviewSet])
  -> ImportReviewExercise
{
  ImportReviewExercise(
    id: UUID(), rawName: "低杠深蹲", boundExerciseID: boundID, isMainLift: mainLift, note: nil,
    sets: sets)
}

private func week(
  blockIndex: Int, selected: Bool, exercise: ImportReviewExercise, dayOfWeek: Int = 0
) -> ImportReviewWeek {
  ImportReviewWeek(
    id: UUID(),
    blockIndex: blockIndex,
    isSelected: selected,
    days: [ImportReviewDay(id: UUID(), dayOfWeek: dayOfWeek, exercises: [exercise])]
  )
}

@Test func assemblesPerSetTargetsAndRenumbersWeeks() throws {
  var counter = 0
  let assembler = ImportPlanAssembler(now: { fixedNow }, makeID: { makeID(&counter) })
  let traineeID = UUID()
  let weeks = [
    week(
      blockIndex: 0, selected: true,
      exercise: reviewExercise(sets: [
        reviewSet(1, weight: "100"), reviewSet(2, weight: "105"),
      ])),
    week(
      blockIndex: 1, selected: true,
      exercise: reviewExercise(sets: [
        reviewSet(1, weight: "110"), reviewSet(2, weight: "115"),
      ])),
  ]

  let assembled = try assembler.assemble(
    traineeID: traineeID, coachID: nil, name: "导入", startDate: fixedNow, weeks: weeks)

  #expect(assembled.plan.planWeeks == 2)
  #expect(assembled.plan.traineeID == traineeID)
  #expect(assembled.days.map(\.weekNumber) == [1, 2])
  #expect(assembled.days.allSatisfy { $0.dayOfWeek == 1 })  // 0-based 0 → 1-based 1
  #expect(
    assembled.sets.map(\.targetValue) == [Decimal(100), Decimal(105), Decimal(110), Decimal(115)])
  #expect(assembled.sets.allSatisfy { $0.intensityMode == .weight })
}

@Test func deselectingFirstWeekRenumbersRemainingToOne() throws {
  var counter = 0
  let assembler = ImportPlanAssembler(now: { fixedNow }, makeID: { makeID(&counter) })
  let weeks = [
    week(
      blockIndex: 0, selected: false, exercise: reviewExercise(sets: [reviewSet(1, weight: "100")])),
    week(
      blockIndex: 1, selected: true, exercise: reviewExercise(sets: [reviewSet(1, weight: "110")])),
  ]

  let assembled = try assembler.assemble(
    traineeID: UUID(), coachID: nil, name: "导入", startDate: fixedNow, weeks: weeks)

  #expect(assembled.plan.planWeeks == 1)
  #expect(assembled.days.map(\.weekNumber) == [1])
  #expect(assembled.sets.map(\.targetValue) == [Decimal(110)])
}

@Test func endDateSpansSelectedWeeks() throws {
  let assembler = ImportPlanAssembler(now: { fixedNow }, makeID: { UUID() })
  let weeks = [
    week(
      blockIndex: 0, selected: true, exercise: reviewExercise(sets: [reviewSet(1, weight: "100")])),
    week(
      blockIndex: 1, selected: true, exercise: reviewExercise(sets: [reviewSet(1, weight: "110")])),
  ]

  let assembled = try assembler.assemble(
    traineeID: UUID(), coachID: nil, name: "导入", startDate: fixedNow, weeks: weeks)

  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC")!
  let expectedEnd = calendar.date(
    byAdding: .day, value: 13, to: calendar.startOfDay(for: fixedNow))!
  #expect(assembled.plan.endDate == expectedEnd)
}

@Test func assembledTreeIsInternallyLinked() throws {
  let assembler = ImportPlanAssembler(now: { fixedNow }, makeID: { UUID() })
  let weeks = [
    week(
      blockIndex: 0, selected: true,
      exercise: reviewExercise(sets: [reviewSet(1, weight: "100"), reviewSet(2, weight: "105")]))
  ]

  let assembled = try assembler.assemble(
    traineeID: UUID(), coachID: nil, name: "导入", startDate: fixedNow, weeks: weeks)

  let dayIDs = Set(assembled.days.map(\.id))
  let exerciseIDs = Set(assembled.exercises.map(\.id))
  #expect(assembled.days.allSatisfy { $0.planID == assembled.plan.id })
  #expect(assembled.exercises.allSatisfy { dayIDs.contains($0.planDayID) })
  #expect(assembled.sets.allSatisfy { exerciseIDs.contains($0.planExerciseID) })
  #expect(assembled.sets.map(\.coachNote) == [nil, nil])
}

@Test func incompleteSelectionThrows() {
  let assembler = ImportPlanAssembler(now: { fixedNow }, makeID: { UUID() })
  // Unbound exercise → cannot publish.
  let weeks = [
    week(
      blockIndex: 0, selected: true,
      exercise: reviewExercise(boundID: nil, sets: [reviewSet(1, weight: "100")]))
  ]
  #expect(throws: ImportAssemblyError.self) {
    try assembler.assemble(
      traineeID: UUID(), coachID: nil, name: "导入", startDate: fixedNow, weeks: weeks)
  }
}

@Test func publishesThroughRepository() async throws {
  let assembler = ImportPlanAssembler(now: { fixedNow }, makeID: { UUID() })
  let repository = InMemoryPlanRepository(students: [], catalog: [])
  let weeks = [
    week(
      blockIndex: 0, selected: true, exercise: reviewExercise(sets: [reviewSet(1, weight: "100")]))
  ]
  let assembled = try assembler.assemble(
    traineeID: UUID(), coachID: nil, name: "导入", startDate: fixedNow, weeks: weeks)

  // Shape is accepted by the real publish signature without throwing.
  try await repository.publishPlan(
    plan: assembled.plan, days: assembled.days, exercises: assembled.exercises, sets: assembled.sets
  )
}
