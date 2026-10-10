import CoreModels
import Foundation

struct ProfileMenuValues: Equatable, Sendable {
  let about: String
  let health: String
  let meet: String
  let note: String

  static func make(profile: OnboardingProfile, locale: Locale = .current) -> Self {
    let presentation = MyProfileV3Presentation.make(
      profile: profile, readiness: nil, restTimer: .automatic)
    let count = profile.injuryAreas.filter { $0 != .other }.count
    let health: String
    if count > 0 {
      health = StudentStrings.replacing(.profileInjuries, values: ["\(count)"], locale: locale)
    } else {
      health = StudentStrings.localized(
        profile.injuryAreas.isEmpty ? .profileNoInjuries : .myProfileV3Presentation008,
        locale: locale)
    }
    return Self(
      about: profile.heightCm == nil && profile.weightKg == nil
        ? "—" : presentation.heightAndWeight,
      health: health,
      meet: profile.isCompeting == true && profile.competitionDate != nil
        ? presentation.competition : "—",
      note: (profile.noteToCoach?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        ? "—" : StudentStrings.localized(.profileAdded, locale: locale)
    )
  }
}
