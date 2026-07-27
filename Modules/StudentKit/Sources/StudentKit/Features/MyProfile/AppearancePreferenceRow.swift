import DesignSystem
import SwiftUI

/// Inline three-way appearance picker for the preferences group. Writes
/// through @AppStorage so the app-level scheme resolver reacts live.
@available(iOS 17.0, macOS 14.0, *)
struct AppearancePreferenceRow: View {
  @AppStorage(MeetPRAppearance.storageKey)
  private var storedPreference = MeetPRAppearance.system.rawValue

  var body: some View {
    HStack(spacing: MeetPRSpacing.space3) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
        Text("外观")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textMuted)
        Text(selection.label)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
      }
      Spacer()
      HStack(spacing: MeetPRSpacing.point6) {
        ForEach(MeetPRAppearance.allCases, id: \.self) { option in
          optionChip(option)
        }
      }
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point14)
    .frame(minHeight: 68)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("外观，当前\(selection.label)")
  }

  private var selection: MeetPRAppearance {
    MeetPRAppearance(rawValue: storedPreference) ?? .system
  }

  private func optionChip(_ option: MeetPRAppearance) -> some View {
    let isSelected = option == selection
    return Button {
      storedPreference = option.rawValue
    } label: {
      Text(option.label)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
        .foregroundStyle(
          isSelected ? Color.MeetPR.gold500 : Color.MeetPR.textMuted
        )
        .padding(.horizontal, MeetPRSpacing.point10)
        .frame(minHeight: 34)
        .background(
          isSelected
            ? Color.MeetPR.gold500.opacity(0.14)
            : Color.MeetPR.surfaceElevated
        )
        .clipShape(.capsule)
        .overlay {
          Capsule().stroke(
            isSelected
              ? Color.MeetPR.gold500.opacity(0.5)
              : Color.MeetPR.borderDefault,
            lineWidth: 1
          )
        }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }
}
