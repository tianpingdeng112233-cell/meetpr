import DesignSystem
import SwiftUI

/// Writes the existing preference key so the student theme changes immediately.
struct AppearancePreferenceRow: View {
  @AppStorage(MeetPRAppearance.storageKey)
  private var storedPreference = MeetPRAppearance.defaultPreference.rawValue

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point10) {
      Text(StudentStrings.localized(.appearancePreferenceRow001))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      ProfileAppearanceOptions(
        selection: Binding(
          get: { MeetPRAppearance(rawValue: storedPreference) ?? .defaultPreference },
          set: { storedPreference = $0.rawValue }))
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point14)
  }
}

struct ProfileAppearanceOptions: View {
  @Binding var selection: MeetPRAppearance

  var body: some View {
    HStack(spacing: MeetPRSpacing.point6) {
      ForEach(MeetPRAppearance.allCases) { option in
        StudentSelectionBlock(title: option.label, isSelected: option == selection) {
          selection = option
        }
      }
    }
  }
}
