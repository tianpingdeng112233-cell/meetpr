import CoreModels
import Foundation
import Testing

@testable import StudentKit

private func fullProfile() -> OnboardingProfile {
  StudentDemoSeed.makeOnboardingProfile(studentID: OnboardingFixtures.studentId)
}

private func emptyProfile() -> OnboardingProfile {
  OnboardingProfile(
    userId: OnboardingFixtures.studentId,
    createdAt: OnboardingFixtures.serverUpdatedAt,
    updatedAt: OnboardingFixtures.serverUpdatedAt
  )
}

/// Frozen "now" for age math: 2026-06-11.
private let now = DateOnly.date(from: "2026-06-11") ?? Date()

@Test func basicsSummaryFormatsGenderAgeHeightWeight() {
  // birth 2001-03-15 → 25 on 2026-06-11.
  #expect(OnboardingSummaryFormatter.basics(fullProfile(), now: now) == "男 · 25岁 · 178cm · 83.00kg")
}

@Test func ageIsWholeYearCalendarDifference() {
  #expect(OnboardingSummaryFormatter.age(birthDate: "2001-03-15", now: now) == 25)
  // Birthday not yet reached this year → still 24.
  #expect(OnboardingSummaryFormatter.age(birthDate: "2001-08-15", now: now) == 24)
  #expect(OnboardingSummaryFormatter.age(birthDate: nil, now: now) == nil)
  #expect(OnboardingSummaryFormatter.age(birthDate: "garbage", now: now) == nil)
}

@Test func backgroundSummaryFormatsYearsAndStances() {
  #expect(OnboardingSummaryFormatter.background(fullProfile()) == "3 年 · 低杠深蹲 · 传统硬拉")
}

@Test func oneRMSummaryUsesSBDShorthand() {
  #expect(OnboardingSummaryFormatter.oneRM(fullProfile()) == "S 180 · B 120 · D 220 (kg)")
}

@Test func environmentSummaryOrdersDaysAndShowsTier() {
  #expect(
    OnboardingSummaryFormatter.environment(fullProfile()) == "周一·三·五·六 (4天/周) · 商业健身房")
}

@Test func recoverySummaryUsesWikiScaleLabels() {
  #expect(
    OnboardingSummaryFormatter.recovery(fullProfile()) == "强度:中等 压力:较高 恢复:约2天 睡眠:7h")
}

@Test func materialsSummaryHidesZeroUploads() {
  // Demo profile has no uploads (degraded Step 6) → only muscle groups.
  #expect(OnboardingSummaryFormatter.materials(fullProfile()) == "想增强:股四头/腘绳肌/肩")
}

@Test func competitionSummaryShowsDateAndClassOrOptOut() {
  let profile = fullProfile()
  #expect(
    OnboardingSummaryFormatter.competition(profile)
      == "\(profile.competitionDate ?? "") · IPF 83kg")

  var draft = OnboardingDraft.from(profile)
  draft.isCompeting = false
  draft.competitionDate = nil
  let optedOut = InMemoryOnboardingRepository.applied(
    draft.patch(forStep: 7),
    to: profile,
    updatedAt: now
  )
  #expect(OnboardingSummaryFormatter.competition(optedOut) == "未填写")
}

@Test func injuriesSummaryCombinesNotesAndAreas() {
  #expect(OnboardingSummaryFormatter.injuries(fullProfile()) == "左肩撞击综合征 (肩)")
  #expect(OnboardingSummaryFormatter.injuries(emptyProfile()) == "无伤病记录")
}

@Test func emptyProfileSummariesFallBackToPlaceholder() {
  let profile = emptyProfile()
  #expect(OnboardingSummaryFormatter.basics(profile, now: now) == "未填写")
  #expect(OnboardingSummaryFormatter.oneRM(profile) == "未填写")
  #expect(OnboardingSummaryFormatter.recovery(profile) == "未填写")
  #expect(OnboardingSummaryFormatter.materials(profile) == "未上传资料")
}

@Test func spec085ProfileMeetAndNoteHaveIndependentSummaries() {
  let profile = OnboardingProfile(
    userId: UUID(), weightKg: 83.5, isCompeting: true,
    competitionDate: "2026-11-01", targetWeightClass: "83kg",
    noteToCoach: "Original note\nKeep this second line",
    createdAt: now, updatedAt: now)
  #expect(OnboardingSummaryFormatter.competition(profile) == "2026-11-01 · 83kg")
  #expect(OnboardingSummaryFormatter.note(profile) == "Original note")
  #expect(OnboardingDraft.from(profile).noteToCoach == "Original note\nKeep this second line")
  #expect(OnboardingSummaryFormatter.basics(profile, now: now) == "83.50kg")
  let presentation = MyProfileV3Presentation.make(
    profile: profile, readiness: nil, restTimer: .automatic)
  #expect(presentation.heightAndWeight == "83.50 kg")
  for competing: Bool? in [nil, false, true] {
    let withoutDate = OnboardingProfile(
      userId: UUID(), isCompeting: competing, targetWeightClass: "83kg",
      noteToCoach: "Original note", createdAt: now, updatedAt: now)
    #expect(OnboardingSummaryFormatter.competition(withoutDate) == "未填写")
    #expect(OnboardingSummaryFormatter.note(withoutDate) == "Original note")
  }
}
