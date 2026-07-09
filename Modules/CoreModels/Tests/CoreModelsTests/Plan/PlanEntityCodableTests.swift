import CoreModels
import Foundation
import Testing

@Test func exerciseCodableRoundTripPreservesCatalogFields() throws {
  let exercise = try makeExercise()

  let json = try encodedJSONString(exercise)
  let decodedExercise = try MeetPRCodec.decoder.decode(Exercise.self, from: Data(json.utf8))

  #expect(decodedExercise == exercise)
  #expect(json.contains(#""exercise_type":"main_lift_variation""#))
  #expect(json.contains(#""main_lift_family":"squat""#))
  #expect(json.contains(#""created_by_coach_id":"50000000-0000-0000-0000-000000000002""#))
}

@Test func trainingPlanCodableRoundTripPreservesPlanFields() throws {
  let plan = try makeTrainingPlan()

  let json = try encodedJSONString(plan)
  let decodedPlan = try MeetPRCodec.decoder.decode(TrainingPlan.self, from: Data(json.utf8))

  #expect(decodedPlan == plan)
  #expect(json.contains(#""plan_weeks":4"#))
  #expect(json.contains(#""source":"coach""#))
  #expect(json.contains(#""status":"draft""#))
}

@Test func planDayCodableRoundTripPreservesWeekFields() throws {
  let day = try makePlanDay()

  let json = try encodedJSONString(day)
  let decodedDay = try MeetPRCodec.decoder.decode(PlanDay.self, from: Data(json.utf8))

  #expect(decodedDay == day)
  #expect(json.contains(#""day_of_week":1"#))
  #expect(json.contains(#""week_number":2"#))
}

@Test func planExerciseCodableRoundTripPreservesMainLiftTrue() throws {
  let exercise = try makePlanExercise(isMainLift: true)

  let json = try encodedJSONString(exercise)
  let decodedExercise = try MeetPRCodec.decoder.decode(PlanExercise.self, from: Data(json.utf8))

  #expect(decodedExercise == exercise)
  #expect(json.contains(#""is_main_lift":true"#))
}

@Test func planExerciseCodableRoundTripPreservesMainLiftFalse() throws {
  let exercise = try makePlanExercise(isMainLift: false)

  let json = try encodedJSONString(exercise)
  let decodedExercise = try MeetPRCodec.decoder.decode(PlanExercise.self, from: Data(json.utf8))

  #expect(decodedExercise == exercise)
  #expect(json.contains(#""is_main_lift":false"#))
}

@Test func planSetWeightCodableRoundTripPreservesDecimalString() throws {
  let set = try makePlanSet(
    targetReps: 5,
    targetRepsMax: nil,
    intensityMode: .weight,
    targetValue: "180.5",
    setType: .working
  )

  let json = try encodedJSONString(set)
  let decodedSet = try MeetPRCodec.decoder.decode(PlanSet.self, from: Data(json.utf8))

  #expect(decodedSet == set)
  #expect(json.contains(#""intensity_mode":"weight""#))
  #expect(json.contains(#""target_value":"180.5""#))
}

@Test func planSetRPECodableRoundTripPreservesDecimalString() throws {
  let set = try makePlanSet(
    targetReps: 8,
    targetRepsMax: nil,
    intensityMode: .rpe,
    targetValue: "7.5",
    setType: .working
  )

  let json = try encodedJSONString(set)
  let decodedSet = try MeetPRCodec.decoder.decode(PlanSet.self, from: Data(json.utf8))

  #expect(decodedSet == set)
  #expect(json.contains(#""intensity_mode":"rpe""#))
  #expect(json.contains(#""target_value":"7.5""#))
}

@Test func planSetTargetRepsRangeEncodesMax() throws {
  let set = try makePlanSet(
    targetReps: 8,
    targetRepsMax: 12,
    intensityMode: .weight,
    targetValue: "100",
    setType: .backoff
  )

  let json = try encodedJSONString(set)

  #expect(json.contains(#""target_reps":8"#))
  #expect(json.contains(#""target_reps_max":12"#))
}

@Test func planSetRestSecondsEncodesPlainIntAndDecodesMissingAsNil() throws {
  let set = try makePlanSet(
    targetReps: 5,
    targetRepsMax: nil,
    intensityMode: .rpe,
    targetValue: "8",
    setType: .working,
    restSeconds: 195
  )

  let json = try encodedJSONString(set)
  let decodedSet = try MeetPRCodec.decoder.decode(PlanSet.self, from: Data(json.utf8))
  let legacySet = try MeetPRCodec.decoder.decode(PlanSet.self, from: Data(legacyPlanSetJSON.utf8))

  #expect(decodedSet.restSeconds == 195)
  #expect(json.contains(#""rest_seconds":195"#))
  #expect(legacySet.restSeconds == nil)
}

@Test func prescribedSetRestSecondsEncodesPlainIntAndDecodesMissingAsNil() throws {
  let set = PrescribedSet(
    id: try fixtureUUID("90000000-0000-0000-0000-000000000011"),
    setIndex: 1,
    weightKg: nil,
    reps: 5,
    repsMax: nil,
    rpe: 8,
    restSeconds: 210
  )

  let json = try encodedJSONString(set)
  let decodedSet = try MeetPRCodec.decoder.decode(PrescribedSet.self, from: Data(json.utf8))
  let legacySet = try MeetPRCodec.decoder.decode(
    PrescribedSet.self,
    from: Data(legacyPrescribedSetJSON.utf8)
  )

  #expect(decodedSet.restSeconds == 210)
  #expect(json.contains(#""rest_seconds":210"#))
  #expect(legacySet.restSeconds == nil)
}

@Test func planSetTargetRepsExactOmitsMax() throws {
  let set = try makePlanSet(
    targetReps: 5,
    targetRepsMax: nil,
    intensityMode: .weight,
    targetValue: "140",
    setType: .working
  )

  let json = try encodedJSONString(set)

  #expect(json.contains(#""target_reps":5"#))
  #expect(!json.contains(#""target_reps_max":"#))
}

@Test func studentSetLogMissingAssumedAndFailedDecodeFalseAndEncode() throws {
  let json = """
    {
      "id": "91000000-0000-0000-0000-000000000001",
      "student_id": "91000000-0000-0000-0000-000000000002",
      "plan_exercise_id": "91000000-0000-0000-0000-000000000003",
      "set_index": 0,
      "logged_at": "2026-05-22T12:00:00Z",
      "weight_kg": "140",
      "reps": 3,
      "rpe": "9",
      "completed": true
    }
    """

  let decoded = try MeetPRCodec.decoder.decode(StudentSetLog.self, from: Data(json.utf8))
  let failedLog = StudentSetLog(
    id: decoded.id,
    studentID: decoded.studentID,
    planExerciseID: decoded.planExerciseID,
    setIndex: decoded.setIndex,
    loggedAt: decoded.loggedAt,
    weightKg: decoded.weightKg,
    reps: decoded.reps,
    rpe: decoded.rpe,
    completed: decoded.completed,
    failed: true
  )
  let encoded = try encodedJSONString(failedLog)

  #expect(!decoded.failed)
  #expect(!decoded.assumed)
  #expect(encoded.contains(#""failed":true"#))
  #expect(encoded.contains(#""assumed":false"#))
}

@Test func planSetCoachNoteCodableRoundTripsAndDecodesMissingAsNil() throws {
  let set = PlanSet(
    id: try fixtureUUID("90000000-0000-0000-0000-000000000001"),
    planExerciseID: try fixtureUUID("80000000-0000-0000-0000-000000000001"),
    setNumber: 1,
    targetReps: 5,
    intensityMode: .weight,
    targetValue: try fixtureDecimal("100"),
    setType: .working,
    coachNote: "节奏3-1-0",
    createdAt: createdAt()
  )

  let json = try encodedJSONString(set)
  let decodedSet = try MeetPRCodec.decoder.decode(PlanSet.self, from: Data(json.utf8))
  let legacySet = try MeetPRCodec.decoder.decode(PlanSet.self, from: Data(legacyPlanSetJSON.utf8))

  #expect(decodedSet == set)
  #expect(decodedSet.coachNote == "节奏3-1-0")
  #expect(json.contains(#""coach_note":"节奏3-1-0""#))
  #expect(legacySet.coachNote == nil)
}

@Test func planSetCoachNoteOmittedWhenNil() throws {
  let set = try makePlanSet(
    targetReps: 5,
    targetRepsMax: nil,
    intensityMode: .weight,
    targetValue: "140",
    setType: .working
  )

  let json = try encodedJSONString(set)

  #expect(set.coachNote == nil)
  #expect(!json.contains("coach_note"))
}

@Test func prescribedSetCoachNoteCodableRoundTripsAndDecodesMissingAsNil() throws {
  let set = PrescribedSet(
    id: try fixtureUUID("90000000-0000-0000-0000-000000000011"),
    setIndex: 1,
    weightKg: nil,
    reps: 5,
    repsMax: nil,
    rpe: 8,
    coachNote: "70%top"
  )

  let json = try encodedJSONString(set)
  let decodedSet = try MeetPRCodec.decoder.decode(PrescribedSet.self, from: Data(json.utf8))
  let legacySet = try MeetPRCodec.decoder.decode(
    PrescribedSet.self,
    from: Data(legacyPrescribedSetJSON.utf8)
  )

  #expect(decodedSet == set)
  #expect(decodedSet.coachNote == "70%top")
  #expect(json.contains(#""coach_note":"70%top""#))
  #expect(legacySet.coachNote == nil)
}

@Test func exerciseFacetMultiSelectEncodesArrays() throws {
  let exercise = try makeExercise()

  let json = try encodedJSONString(exercise)

  #expect(json.contains(#""muscle_groups":["quad","core"]"#))
  #expect(json.contains(#""equipment":["barbell"]"#))
  #expect(json.contains(#""movement_pattern":["squat"]"#))
}

private func makeExercise() throws -> Exercise {
  Exercise(
    id: try fixtureUUID("50000000-0000-0000-0000-000000000001"),
    name: "暂停深蹲",
    exerciseType: .mainLiftVariation,
    mainLiftFamily: .squat,
    isCompetitionLift: false,
    muscleGroups: [.quad, .core],
    equipment: [.barbell],
    movementPattern: [.squat],
    createdByCoachID: try fixtureUUID("50000000-0000-0000-0000-000000000002"),
    createdAt: createdAt()
  )
}

private func makeTrainingPlan() throws -> TrainingPlan {
  TrainingPlan(
    id: try fixtureUUID("60000000-0000-0000-0000-000000000001"),
    coachID: try fixtureUUID("60000000-0000-0000-0000-000000000002"),
    traineeID: try fixtureUUID("60000000-0000-0000-0000-000000000003"),
    name: "四周备赛周期",
    startDate: Date(timeIntervalSince1970: 1_777_248_000),
    endDate: Date(timeIntervalSince1970: 1_779_667_200),
    planWeeks: 4,
    source: .coach,
    sourceTemplateID: nil,
    status: .draft,
    createdAt: createdAt(),
    updatedAt: updatedAt()
  )
}

private func makePlanDay() throws -> PlanDay {
  PlanDay(
    id: try fixtureUUID("70000000-0000-0000-0000-000000000001"),
    planID: try fixtureUUID("60000000-0000-0000-0000-000000000001"),
    dayOfWeek: 1,
    weekNumber: 2,
    sortOrder: 0
  )
}

private func makePlanExercise(isMainLift: Bool) throws -> PlanExercise {
  PlanExercise(
    id: try fixtureUUID("80000000-0000-0000-0000-000000000001"),
    planDayID: try fixtureUUID("70000000-0000-0000-0000-000000000001"),
    exerciseID: try fixtureUUID("50000000-0000-0000-0000-000000000001"),
    isMainLift: isMainLift,
    sortOrder: 1,
    notes: "保持技术一致"
  )
}

private func makePlanSet(
  targetReps: Int,
  targetRepsMax: Int?,
  intensityMode: IntensityMode,
  targetValue: String,
  setType: SetType,
  restSeconds: Int? = nil
) throws -> PlanSet {
  PlanSet(
    id: try fixtureUUID("90000000-0000-0000-0000-000000000001"),
    planExerciseID: try fixtureUUID("80000000-0000-0000-0000-000000000001"),
    setNumber: 1,
    targetReps: targetReps,
    targetRepsMax: targetRepsMax,
    intensityMode: intensityMode,
    targetValue: try fixtureDecimal(targetValue),
    setType: setType,
    restSeconds: restSeconds,
    createdAt: createdAt()
  )
}

private let legacyPlanSetJSON = """
  {
    "id": "90000000-0000-0000-0000-000000000001",
    "plan_exercise_id": "80000000-0000-0000-0000-000000000001",
    "set_number": 1,
    "target_reps": 5,
    "target_reps_max": null,
    "intensity_mode": "rpe",
    "target_value": "8",
    "set_type": "working",
    "created_at": "2026-04-25T12:00:00Z"
  }
  """

private let legacyPrescribedSetJSON = """
  {
    "id": "90000000-0000-0000-0000-000000000011",
    "set_index": 1,
    "weight_kg": null,
    "reps": 5,
    "reps_max": null,
    "rpe": "8"
  }
  """
