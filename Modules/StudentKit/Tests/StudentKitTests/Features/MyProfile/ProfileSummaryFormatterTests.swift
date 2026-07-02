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
  #expect(OnboardingSummaryFormatter.basics(fullProfile(), now: now) == "男 · 25岁 · 178cm · 83kg")
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
  #expect(OnboardingSummaryFormatter.competition(fullProfile()) == "备赛: 2026-07-25 · IPF 83kg")

  var draft = OnboardingDraft.from(fullProfile())
  draft.isCompeting = false
  draft.competitionDate = nil
  let optedOut = InMemoryOnboardingRepository.applied(
    draft.patch(forStep: 7),
    to: fullProfile(),
    updatedAt: now
  )
  #expect(OnboardingSummaryFormatter.competition(optedOut) == "暂不备赛")
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
