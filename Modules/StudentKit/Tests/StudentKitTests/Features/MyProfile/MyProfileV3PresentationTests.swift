import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func profileV3PresentationUsesCurrentReadinessAndOnboardingBaseline() {
  let profile = StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
  let readiness = ReadinessCheckin(
    id: UUID(),
    studentId: StudentDemoSeed.studentID,
    checkinDate: "2026-07-27",
    sleepQuality: 4,
    mood: 3,
    stress: 2,
    muscleFatigue: [],
    submittedAt: Date(timeIntervalSince1970: 1_774_742_400)
  )

  let presentation = MyProfileV3Presentation.make(
    profile: profile,
    readiness: readiness,
    restTimer: .automatic
  )

  #expect(presentation.sbdTotalKg == 520)
  #expect(presentation.recoveryChips == ["睡眠 4/5", "状态 3/5", "压力 2/5"])
  #expect(presentation.injuryChips == ["肩部伤病"])
  #expect(presentation.restTimer == "自动 (按 RPE)")
  #expect(presentation.competitionDate == profile.competitionDate)
  #expect(presentation.trainingEnvironment.contains("4天/周"))
}

@Test func profileV3PresentationFallsBackToRecoveryProfileAndFixedTimer() {
  let profile = StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)

  let presentation = MyProfileV3Presentation.make(
    profile: profile,
    readiness: nil,
    restTimer: .fixed(seconds: 180)
  )

  #expect(presentation.recoveryChips == ["中等强度", "较高压力", "约2天恢复"])
  #expect(presentation.restTimer == "固定 3:00")
}
