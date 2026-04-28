import CoreModels
import Foundation
import Testing

@Test func liftFamilyEncodesRawValue() throws {
  try expectEncoded(LiftFamily.deadlift, contains: #""deadlift""#)
}

@Test func exerciseTypeEncodesSnakeCaseRawValue() throws {
  try expectEncoded(ExerciseType.mainLiftVariation, contains: #""main_lift_variation""#)
}

@Test func muscleGroupEncodesRawValue() throws {
  try expectEncoded(MuscleGroup.hamstring, contains: #""hamstring""#)
}

@Test func equipmentEncodesRawValue() throws {
  try expectEncoded(Equipment.bodyweight, contains: #""bodyweight""#)
}

@Test func movementPatternEncodesRawValue() throws {
  try expectEncoded(MovementPattern.pull, contains: #""pull""#)
}

@Test func planSourceEncodesRawValue() throws {
  try expectEncoded(PlanSource.algorithm, contains: #""algorithm""#)
}

@Test func planStatusEncodesRawValue() throws {
  try expectEncoded(PlanStatus.paused, contains: #""paused""#)
}

@Test func intensityModeEncodesRawValue() throws {
  try expectEncoded(IntensityMode.rpe, contains: #""rpe""#)
}

@Test func setTypeEncodesRawValue() throws {
  try expectEncoded(SetType.amrap, contains: #""amrap""#)
}

private func expectEncoded<Value: Encodable>(_ value: Value, contains rawValue: String) throws {
  let json = try encodedJSONString(value)

  #expect(json.contains(rawValue))
}
