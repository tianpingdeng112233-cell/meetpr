import DesignSystem
import SwiftUI

/// Lets the student pick between following the device, light, and dark.
///
/// The choice is read back by `meetPRStudentAppearance()` at the student branch
/// of the root router, so switching here re-themes the whole student tab set
/// without a relaunch.
@available(iOS 17.0, macOS 14.0, *)
struct AppearancePreferenceRow: View {
  @AppStorage(MeetPRAppearance.storageKey) private var appearance = MeetPRAppearance.system

  var body: some View {
    HStack(spacing: MeetPRSpacing.space3) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
        Text("外观")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size14))
          .foregroundStyle(Color.MeetPR.textTertiary)
        Text(appearance.label)
          .font(.MeetPR.system(size: MeetPRFontMetrics.size17))
          .foregroundStyle(Color.MeetPR.textPrimary)
      }
      Spacer(minLength: MeetPRSpacing.space3)
      Picker("外观", selection: $appearance) {
        ForEach(MeetPRAppearance.allCases) { option in
          Image(systemName: option.symbolName)
            .accessibilityLabel(option.label)
            .tag(option)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .fixedSize()
    }
    .padding(MeetPRSpacing.space4)
    .frame(minHeight: 64)
  }
}

#Preview("Appearance row") {
  AppearancePreferenceRow()
    .background(Color.MeetPR.surfaceCard)
    .padding()
    .background(Color.MeetPR.bgBase)
}
