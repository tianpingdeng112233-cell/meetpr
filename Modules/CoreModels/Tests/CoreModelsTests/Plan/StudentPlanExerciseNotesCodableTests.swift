import CoreModels
import Foundation
import Testing

// Exercise-level coach note (backend plan_exercises.notes → StudentPlanExercise
// .notes). The student projection is cached as JSON, so the field must round-trip
// and pre-existing cached blobs written before the field existed must still decode.

@Test func studentPlanExerciseNotesRoundTripsAndDecodesMissingAsNil() throws {
  let exercise = StudentPlanExercise(
    id: try fixtureUUID("90000000-0000-0000-0000-000000000021"),
    exercise: try makeCatalogExercise(),
    sequenceIndex: 0,
    prescribedSets: [],
    notes: "顶组留一,腰部有感觉就停"
  )

  let json = try encodedJSONString(exercise)
  let decodedExercise = try MeetPRCodec.decoder.decode(
    StudentPlanExercise.self, from: Data(json.utf8))

  #expect(decodedExercise == exercise)
  #expect(json.contains(#""notes":"顶组留一,腰部有感觉就停""#))

  // Pre-existing cached projections were written before the field existed, so
  // their JSON carries no notes key at all — decode must yield nil, not throw.
  let legacyExercise = StudentPlanExercise(
    id: exercise.id,
    exercise: exercise.exercise,
    sequenceIndex: 0,
    prescribedSets: []
  )
  let legacyJSON = try encodedJSONString(legacyExercise)
  #expect(!legacyJSON.contains(#""notes""#))

  let decodedLegacyExercise = try MeetPRCodec.decoder.decode(
    StudentPlanExercise.self, from: Data(legacyJSON.utf8))
  #expect(decodedLegacyExercise.notes == nil)
}

private func makeCatalogExercise() throws -> Exercise {
  Exercise(
    id: try fixtureUUID("50000000-0000-0000-0000-000000000001"),
    name: "硬拉",
    exerciseType: .mainLift,
    mainLiftFamily: .deadlift,
    isCompetitionLift: true,
    muscleGroups: [.back],
    equipment: [.barbell],
    movementPattern: [.hipHinge],
    createdByCoachID: nil,
    createdAt: Date(timeIntervalSince1970: 1_777_248_000)
  )
}
