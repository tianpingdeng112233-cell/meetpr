import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func profileV3PresentationKeepsRetainedProfileValuesWithReadiness() {
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
  #expect(presentation.injuryChips == ["肩部伤病"])
  #expect(presentation.restTimer == "自动 (按 RPE)")
  #expect(presentation.competitionDate == profile.competitionDate)
}

@Test func profileV3PresentationKeepsCustomTimerWithoutReadiness() {
  let profile = StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)

  let presentation = MyProfileV3Presentation.make(
    profile: profile,
    readiness: nil,
    restTimer: .custom(lowSeconds: 120, midSeconds: 180, highSeconds: 240)
  )

  #expect(presentation.restTimer == "手动设置 2:00/3:00/4:00")
}
