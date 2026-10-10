import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func profileIdentityUsesSessionFallbackAndLetterInitials() {
  #expect(
    ProfileIdentity.displayName(name: " David Shi ", email: "d@example.com", phone: "123")
      == "David Shi")
  #expect(
    ProfileIdentity.displayName(name: " ", email: "d@example.com", phone: "123") == "d@example.com")
  #expect(ProfileIdentity.displayName(email: nil, phone: "+15550102400") == "+15550102400")
  #expect(ProfileIdentity.displayName() == "")
  let examples = [
    "David Shi": "DS", "david": "D", "张三": "张", "david@example.com": "D", "+15550102400": "",
    "": "",
  ]
  for (input, expected) in examples {
    #expect(ProfileIdentity.initials(input) == expected)
  }
  #expect(ProfileIdentity.coachName(status: nil, name: "Coach") == nil)
  #expect(ProfileIdentity.coachName(status: .accepted, name: " Coach ") == "Coach")
  #expect(ProfileIdentity.coachName(status: .pending, name: "Coach") == nil)
  #expect(ProfileIdentity.coachName(status: .rejected, name: "Coach") == nil)
  #expect(ProfileIdentity.coachName(status: .accepted, name: " ") == nil)
}

@Test func profileMenuValuesKeepExistingSummariesAndExplicitEmptyValues() {
  let profile = StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
  let values = ProfileMenuValues.make(profile: profile, locale: Locale(identifier: "en"))
  #expect(values.about == "178 cm · 83.00 kg")
  #expect(values.health == "1 injury")
  #expect(values.meet == OnboardingSummaryFormatter.competition(profile))
  #expect(values.note == "Added")
  let empty = OnboardingProfile(userId: UUID(), createdAt: Date(), updatedAt: Date())
  let blank = ProfileMenuValues.make(profile: empty, locale: Locale(identifier: "en"))
  #expect(blank.about == "—")
  #expect(blank.health == "No injuries")
  #expect(blank.meet == "—")
  #expect(blank.note == "—")
  let partial = OnboardingProfile(
    userId: UUID(), heightCm: 170, injuryAreas: [.other], createdAt: Date(), updatedAt: Date())
  let other = ProfileMenuValues.make(profile: partial, locale: Locale(identifier: "zh-Hans"))
  #expect(other.about == "170 cm")
  #expect(other.health == "其他伤病")
}
