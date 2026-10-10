import CoreModels
import DesignSystem
import SwiftUI

enum ProfileMenuDestination: CaseIterable, Hashable, Sendable {
  case about, health, meet, note, settings

  var title: String {
    switch self {
    case .about: StudentStrings.localized(.profileAbout)
    case .health: StudentStrings.localized(.profileHealth)
    case .meet: StudentStrings.localized(.meetTitle)
    case .note: StudentStrings.localized(.profileNote)
    case .settings: StudentStrings.localized(.profileSettings)
    }
  }

  var icon: String {
    switch self {
    case .about: "person"
    case .health: "heart"
    case .meet: "flag"
    case .note: "pencil"
    case .settings: "slider.horizontal.3"
    }
  }

  var editor: ProfileCardKind? {
    switch self {
    case .meet: .competition
    case .note: .note
    default: nil
    }
  }

  func value(from values: ProfileMenuValues?) -> String? {
    switch self {
    case .about: values?.about
    case .health: values?.health
    case .meet: values?.meet
    case .note: values?.note
    case .settings: nil
    }
  }
}

struct ProfileHomeContent: View {
  let identity: ProfileIdentity
  let state: MyProfileViewModel.State
  let isFailed: Bool
  let onOpen: (ProfileMenuDestination) -> Void
  let onRetry: () -> Void
  let onOneRMInfo: () -> Void

  var body: some View {
    let profile = state.profile
    let values = profile.map { ProfileMenuValues.make(profile: $0) }
    VStack(spacing: MeetPRSpacing.point14) {
      ProfileIdentityCard(
        identity: identity, profile: profile,
        blank: profile == nil && state != .empty, onOneRMInfo: onOneRMInfo)
      VStack(spacing: MeetPRSpacing.point10) {
        if state == .empty {
          MyProfileStateCard(text: StudentStrings.localized(.myProfileView001))
        }
        ForEach(ProfileMenuDestination.allCases, id: \.self) { destination in
          if state != .empty || destination == .settings {
            StudentMenuRow(
              icon: destination.icon, title: destination.title,
              value: destination.value(from: values), action: { onOpen(destination) })
          }
        }
      }
      if isFailed {
        Button(action: onRetry) {
          Text(StudentStrings.localized(.myProfileView002))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
            .foregroundStyle(Color.MeetPR.textMuted)
            .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
        }
      }
    }
  }
}

extension MyProfileViewModel.State {
  var profile: OnboardingProfile? {
    guard case .loaded(let profile) = self else { return nil }
    return profile
  }
}
