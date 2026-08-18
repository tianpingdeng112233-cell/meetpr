import CoreModels
import Foundation
import Testing

@testable import CoachKit

@Test func readinessScalesTextShowsRawValuesWithoutInversion() {
  let checkin = CoachStudentFeatureFixtures.readinessCheckin(checkinDate: "2026-02-02")

  #expect(
    CoachStudentFormatting.readinessScalesText(checkin)
      == CoachSharedStrings.readinessScales(sleep: 4, mood: 3, stress: 2))
}

@Test func readinessFatigueTextOrdersByAllowedChipOrder() {
  // Input deliberately out of chip order (core before quad) — output must
  // follow `ReadinessCheckin.allowedMuscleGroups`.
  let checkin = CoachStudentFeatureFixtures.readinessCheckin(
    checkinDate: "2026-02-02",
    muscleFatigue: [
      MuscleFatigue(muscleGroup: .core, severity: 1),
      MuscleFatigue(muscleGroup: .quad, severity: 3),
      MuscleFatigue(muscleGroup: .shoulder, severity: 2),
    ]
  )

  #expect(
    CoachStudentFormatting.readinessFatigueText(checkin)
      == CoachSharedStrings.fatigue(
        [
          CoachSharedStrings.muscleGroup("coach.shared.muscle.quadriceps") + "("
            + CoachSharedStrings.severity(3) + ")",
          CoachSharedStrings.muscleGroup("coach.shared.muscle.shoulder") + "("
            + CoachSharedStrings.severity(2) + ")",
          CoachSharedStrings.muscleGroup("coach.shared.muscle.coreAndLowerBack") + "("
            + CoachSharedStrings.severity(1) + ")",
        ].joined(separator: " "))
  )
}

@Test func readinessFatigueTextHandlesNoFatigue() {
  let checkin = CoachStudentFeatureFixtures.readinessCheckin(
    checkinDate: "2026-02-02",
    muscleFatigue: []
  )

  #expect(
    CoachStudentFormatting.readinessFatigueText(checkin) == CoachSharedStrings.noMuscleFatigue())
}

@Test func muscleGroupTextCoversAllEightAllowedGroups() {
  let texts = ReadinessCheckin.allowedMuscleGroups.map {
    CoachStudentFormatting.muscleGroupText($0)
  }

  #expect(
    texts == [
      "coach.shared.muscle.quadriceps", "coach.shared.muscle.hamstrings",
      "coach.shared.muscle.glutes", "coach.shared.muscle.back", "coach.shared.muscle.chest",
      "coach.shared.muscle.shoulder", "coach.shared.muscle.triceps",
      "coach.shared.muscle.coreAndLowerBack",
    ])
}

@Test func localDayStringMatchesCheckinDateWireShape() {
  let dayString = CoachStudentFormatting.localDayString(CoachStudentFeatureFixtures.startDate)

  // Device-local day, "yyyy-MM-dd" — the readiness fetch key (spec 030).
  #expect(dayString.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil)
}
