import CoreModels
import Foundation
import Testing

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionMapsSingleWeekSingleExerciseHappyPath() throws {
  let day = ProjFixtures.day(id: ProjFixtures.uuid(50), week: 1, dayOfWeek: 1, sortOrder: 0)
  let exercise = ProjFixtures.exercise(
    id: ProjFixtures.uuid(60),
    dayID: day.id,
    exerciseID: ProjFixtures.squatID,
    isMain: true,
    sortOrder: 0
  )
  let set = ProjFixtures.set(exID: exercise.id, number: 1, reps: 5, value: Decimal(100))

  let view = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(),
    days: [day],
    exercises: [exercise],
    sets: [set],
    catalog: ProjFixtures.catalog(),
    weekIndex: 1
  )

  #expect(view.cycleID == ProjFixtures.planID)
  #expect(view.weekIndex == 1)
  #expect(view.startDate == ProjFixtures.now)
  #expect(view.days.count == 1)

  let outDay = try #require(view.days.first)
  let outExercise = try #require(outDay.exercises.first)
  #expect(outDay.exercises.count == 1)
  #expect(outExercise.exercise.id == ProjFixtures.squatID)
  #expect(outExercise.sequenceIndex == 0)

  let outSet = try #require(outExercise.prescribedSets.first)
  #expect(outExercise.prescribedSets.count == 1)
  #expect(outSet.setIndex == 1)
  #expect(outSet.weightKg == Decimal(100))
  #expect(outSet.reps == 5)
  #expect(outSet.repsMax == nil)
  #expect(outSet.rpe == nil)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionFiltersDaysByWeekIndexPickingThatWeeksValues() throws {
  let dayW1 = ProjFixtures.day(id: ProjFixtures.uuid(50), week: 1, dayOfWeek: 1, sortOrder: 0)
  let dayW2 = ProjFixtures.day(id: ProjFixtures.uuid(51), week: 2, dayOfWeek: 1, sortOrder: 0)
  let exW1 = ProjFixtures.exercise(
    id: ProjFixtures.uuid(60), dayID: dayW1.id, exerciseID: ProjFixtures.squatID,
    isMain: true, sortOrder: 0
  )
  let exW2 = ProjFixtures.exercise(
    id: ProjFixtures.uuid(61), dayID: dayW2.id, exerciseID: ProjFixtures.squatID,
    isMain: true, sortOrder: 0
  )
  let setW1 = ProjFixtures.set(exID: exW1.id, number: 1, value: Decimal(100))
  let setW2 = ProjFixtures.set(exID: exW2.id, number: 1, value: Decimal(110))

  let view = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(),
    days: [dayW1, dayW2],
    exercises: [exW1, exW2],
    sets: [setW1, setW2],
    catalog: ProjFixtures.catalog(),
    weekIndex: 2
  )

  #expect(view.weekIndex == 2)
  #expect(view.days.count == 1)
  let outDay = try #require(view.days.first)
  #expect(outDay.id == dayW2.id)
  let outSet = try #require(outDay.exercises.first?.prescribedSets.first)
  #expect(outSet.weightKg == Decimal(110))
}

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionMapsRepsMaxRangeToRepsMaxFieldLeavingRepsNil() throws {
  let day = ProjFixtures.day(id: ProjFixtures.uuid(50), week: 1, dayOfWeek: 1, sortOrder: 0)
  let exercise = ProjFixtures.exercise(
    id: ProjFixtures.uuid(60), dayID: day.id, exerciseID: ProjFixtures.squatID,
    isMain: true, sortOrder: 0
  )
  let set = ProjFixtures.set(exID: exercise.id, number: 1, reps: 3, repsMax: 5, value: Decimal(90))

  let view = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(), days: [day], exercises: [exercise], sets: [set],
    catalog: ProjFixtures.catalog(), weekIndex: 1
  )

  let outSet = try #require(view.days.first?.exercises.first?.prescribedSets.first)
  #expect(outSet.reps == nil)
  #expect(outSet.repsMax == 5)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionWeightModeSetHasWeightAndNilRPE() throws {
  let day = ProjFixtures.day(id: ProjFixtures.uuid(50), week: 1, dayOfWeek: 1, sortOrder: 0)
  let exercise = ProjFixtures.exercise(
    id: ProjFixtures.uuid(60), dayID: day.id, exerciseID: ProjFixtures.squatID,
    isMain: true, sortOrder: 0
  )
  let set = ProjFixtures.set(exID: exercise.id, number: 1, mode: .weight, value: Decimal(125))

  let view = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(), days: [day], exercises: [exercise], sets: [set],
    catalog: ProjFixtures.catalog(), weekIndex: 1
  )

  let outSet = try #require(view.days.first?.exercises.first?.prescribedSets.first)
  #expect(outSet.weightKg == Decimal(125))
  #expect(outSet.rpe == nil)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionRPEModeSetRoutesValueToRPEFieldLeavingWeightNil() throws {
  let day = ProjFixtures.day(id: ProjFixtures.uuid(50), week: 1, dayOfWeek: 1, sortOrder: 0)
  let exercise = ProjFixtures.exercise(
    id: ProjFixtures.uuid(60), dayID: day.id, exerciseID: ProjFixtures.squatID,
    isMain: true, sortOrder: 0
  )
  let set = ProjFixtures.set(exID: exercise.id, number: 1, mode: .rpe, value: Decimal(8))

  let view = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(), days: [day], exercises: [exercise], sets: [set],
    catalog: ProjFixtures.catalog(), weekIndex: 1
  )

  let outSet = try #require(view.days.first?.exercises.first?.prescribedSets.first)
  #expect(outSet.rpe == Decimal(8))
  #expect(outSet.weightKg == nil)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionOrdersMainLiftBeforeAccessoryBySortOrder() throws {
  let day = ProjFixtures.day(id: ProjFixtures.uuid(50), week: 1, dayOfWeek: 1, sortOrder: 0)
  let accessory = ProjFixtures.exercise(
    id: ProjFixtures.uuid(61), dayID: day.id, exerciseID: ProjFixtures.accessoryID,
    isMain: false, sortOrder: 1
  )
  let main = ProjFixtures.exercise(
    id: ProjFixtures.uuid(60), dayID: day.id, exerciseID: ProjFixtures.squatID,
    isMain: true, sortOrder: 0
  )
  let mainSet = ProjFixtures.set(exID: main.id, number: 1, value: Decimal(150))
  let accessorySet = ProjFixtures.set(exID: accessory.id, number: 1, value: Decimal(40))

  let view = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(), days: [day],
    exercises: [accessory, main], sets: [accessorySet, mainSet],
    catalog: ProjFixtures.catalog(), weekIndex: 1
  )

  let outDay = try #require(view.days.first)
  #expect(outDay.exercises.map(\.exercise.id) == [ProjFixtures.squatID, ProjFixtures.accessoryID])
  #expect(outDay.exercises.map(\.sequenceIndex) == [0, 1])
}

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionExpandsMultipleSetsSortedBySetNumber() throws {
  let day = ProjFixtures.day(id: ProjFixtures.uuid(50), week: 1, dayOfWeek: 1, sortOrder: 0)
  let exercise = ProjFixtures.exercise(
    id: ProjFixtures.uuid(60), dayID: day.id, exerciseID: ProjFixtures.squatID,
    isMain: true, sortOrder: 0
  )
  let set3 = ProjFixtures.set(exID: exercise.id, number: 3, value: Decimal(100))
  let set1 = ProjFixtures.set(exID: exercise.id, number: 1, value: Decimal(100))
  let set2 = ProjFixtures.set(exID: exercise.id, number: 2, value: Decimal(100))

  let view = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(), days: [day], exercises: [exercise],
    sets: [set3, set1, set2], catalog: ProjFixtures.catalog(), weekIndex: 1
  )

  let outExercise = try #require(view.days.first?.exercises.first)
  #expect(outExercise.prescribedSets.count == 3)
  #expect(outExercise.prescribedSets.map(\.setIndex) == [1, 2, 3])
}

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionSkipsExerciseMissingFromCatalog() throws {
  let day = ProjFixtures.day(id: ProjFixtures.uuid(50), week: 1, dayOfWeek: 1, sortOrder: 0)
  let known = ProjFixtures.exercise(
    id: ProjFixtures.uuid(60), dayID: day.id, exerciseID: ProjFixtures.squatID,
    isMain: true, sortOrder: 0
  )
  let unknown = ProjFixtures.exercise(
    id: ProjFixtures.uuid(61), dayID: day.id, exerciseID: ProjFixtures.uuid(199),
    isMain: false, sortOrder: 1
  )
  let knownSet = ProjFixtures.set(exID: known.id, number: 1, value: Decimal(100))
  let unknownSet = ProjFixtures.set(exID: unknown.id, number: 1, value: Decimal(50))

  let view = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(), days: [day], exercises: [known, unknown],
    sets: [knownSet, unknownSet], catalog: ProjFixtures.catalog(), weekIndex: 1
  )

  let outDay = try #require(view.days.first)
  #expect(outDay.exercises.count == 1)
  #expect(outDay.exercises.first?.exercise.id == ProjFixtures.squatID)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionComputesDayDateFromStartDateWeekAndDayOfWeek() throws {
  let dayA = ProjFixtures.day(id: ProjFixtures.uuid(50), week: 1, dayOfWeek: 1, sortOrder: 0)
  let dayB = ProjFixtures.day(id: ProjFixtures.uuid(51), week: 2, dayOfWeek: 3, sortOrder: 1)
  let exA = ProjFixtures.exercise(
    id: ProjFixtures.uuid(60), dayID: dayA.id, exerciseID: ProjFixtures.squatID,
    isMain: true, sortOrder: 0
  )
  let exB = ProjFixtures.exercise(
    id: ProjFixtures.uuid(61), dayID: dayB.id, exerciseID: ProjFixtures.squatID,
    isMain: true, sortOrder: 0
  )

  let viewW1 = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(), days: [dayA], exercises: [exA], sets: [],
    catalog: ProjFixtures.catalog(), weekIndex: 1
  )
  #expect(viewW1.days.first?.date == ProjFixtures.now)

  let viewW2 = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(), days: [dayB], exercises: [exB], sets: [],
    catalog: ProjFixtures.catalog(), weekIndex: 2
  )
  #expect(viewW2.days.first?.date == ProjFixtures.expectedDate(week: 2, dayOfWeek: 3))
}

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionSortsDaysChronologicallyByDayOfWeek() {
  let unsorted = [5, 1, 3].enumerated().map { index, dayOfWeek in
    ProjFixtures.day(
      id: ProjFixtures.uuid(UInt8(50 + index)),
      week: 1,
      dayOfWeek: dayOfWeek,
      sortOrder: index
    )
  }

  let view = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(), days: unsorted, exercises: [], sets: [],
    catalog: ProjFixtures.catalog(), weekIndex: 1
  )

  let dates = view.days.map(\.date)
  #expect(
    dates == [
      ProjFixtures.expectedDate(week: 1, dayOfWeek: 1),
      ProjFixtures.expectedDate(week: 1, dayOfWeek: 3),
      ProjFixtures.expectedDate(week: 1, dayOfWeek: 5),
    ])
}

@available(iOS 17.0, macOS 14.0, *)
@Test func projectionReturnsEmptyDaysWhenNoDayMatchesWeekIndex() {
  let day = ProjFixtures.day(id: ProjFixtures.uuid(50), week: 1, dayOfWeek: 1, sortOrder: 0)

  let view = PlanToStudentProjection.project(
    plan: ProjFixtures.plan(), days: [day], exercises: [], sets: [],
    catalog: ProjFixtures.catalog(), weekIndex: 3
  )

  #expect(view.weekIndex == 3)
  #expect(view.days.isEmpty)
}

@available(iOS 17.0, macOS 14.0, *)
private enum ProjFixtures {
  static let now = Date(timeIntervalSince1970: 1_766_630_400)
  static let planID = uuid(1)
  static let traineeID = uuid(2)
  static let squatID = PlanningFixtures.squatID
  static let accessoryID = PlanningFixtures.accessoryID

  static func uuid(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, byte))
  }

  static func catalog() -> [Exercise] { PlanningFixtures.catalog() }

  static func plan(startDate: Date = now) -> TrainingPlan {
    TrainingPlan(
      id: planID,
      coachID: uuid(3),
      traineeID: traineeID,
      name: "测试计划",
      startDate: startDate,
      endDate: startDate.addingTimeInterval(2_332_800),
      planWeeks: 4,
      source: .coach,
      status: .published,
      createdAt: now,
      updatedAt: now
    )
  }

  static func day(id: UUID, week: Int, dayOfWeek: Int, sortOrder: Int) -> PlanDay {
    PlanDay(id: id, planID: planID, dayOfWeek: dayOfWeek, weekNumber: week, sortOrder: sortOrder)
  }

  static func exercise(
    id: UUID,
    dayID: UUID,
    exerciseID: UUID,
    isMain: Bool,
    sortOrder: Int
  ) -> PlanExercise {
    PlanExercise(
      id: id,
      planDayID: dayID,
      exerciseID: exerciseID,
      isMainLift: isMain,
      sortOrder: sortOrder
    )
  }

  static func set(
    id: UUID = UUID(),
    exID: UUID,
    number: Int,
    reps: Int = 5,
    repsMax: Int? = nil,
    mode: IntensityMode = .weight,
    value: Decimal,
    type: SetType = .working
  ) -> PlanSet {
    PlanSet(
      id: id,
      planExerciseID: exID,
      setNumber: number,
      targetReps: reps,
      targetRepsMax: repsMax,
      intensityMode: mode,
      targetValue: value,
      setType: type,
      createdAt: now
    )
  }

  static func expectedDate(week: Int, dayOfWeek: Int, from startDate: Date = now) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    let offset = (week - 1) * 7 + (dayOfWeek - 1)
    return calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
  }
}
