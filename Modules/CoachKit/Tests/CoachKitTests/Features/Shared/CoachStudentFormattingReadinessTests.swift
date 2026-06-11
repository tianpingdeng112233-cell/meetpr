import CoreModels
import Foundation
import Testing

@testable import CoachKit

@Test func readinessScalesTextShowsRawValuesWithoutInversion() {
  let checkin = CoachStudentFeatureFixtures.readinessCheckin(checkinDate: "2026-02-02")

  #expect(CoachStudentFormatting.readinessScalesText(checkin) == "睡眠 4 · 状态 3 · 压力 2")
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
    CoachStudentFormatting.readinessFatigueText(checkin) == "疲劳：股四(重) 肩(中) 核心·下背(轻)"
  )
}

@Test func readinessFatigueTextHandlesNoFatigue() {
  let checkin = CoachStudentFeatureFixtures.readinessCheckin(
    checkinDate: "2026-02-02",
    muscleFatigue: []
  )

  #expect(CoachStudentFormatting.readinessFatigueText(checkin) == "无肌群疲劳")
}

@Test func muscleGroupTextCoversAllEightAllowedGroups() {
  let texts = ReadinessCheckin.allowedMuscleGroups.map(CoachStudentFormatting.muscleGroupText)

  #expect(texts == ["股四", "腘绳", "臀", "背", "胸", "肩", "肱三头", "核心·下背"])
}

@Test func localDayStringMatchesCheckinDateWireShape() {
  let dayString = CoachStudentFormatting.localDayString(CoachStudentFeatureFixtures.startDate)

  // Device-local day, "yyyy-MM-dd" — the readiness fetch key (spec 030).
  #expect(dayString.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil)
}
