import DesignSystem
import SwiftUI

enum DailyBodyWeightPreference {
  static func key(studentID: UUID) -> String {
    "meetpr.dailyBodyWeight.\(studentID.uuidString)"
  }
}

struct DailyBodyWeightPreferenceRow: View {
  @AppStorage private var enabled: Bool

  init(studentID: UUID) {
    _enabled = AppStorage(wrappedValue: false, DailyBodyWeightPreference.key(studentID: studentID))
  }

  var body: some View {
    Toggle(isOn: $enabled) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
        Text(StudentStrings.localized(.dailyWeightSetting))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15))
        Text(StudentStrings.localized(.dailyWeightSettingHelp))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
    }
    .toggleStyle(DailyBodyWeightToggleStyle())
    .padding(MeetPRSpacing.space4)
    .accessibilityIdentifier("settings.dailyBodyWeight")
  }
}

private struct DailyBodyWeightToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: MeetPRSpacing.space3) {
      configuration.label
      Spacer(minLength: 0)
      Button {
        configuration.isOn.toggle()
      } label: {
        Capsule()
          .fill(
            configuration.isOn
              ? AnyShapeStyle(
                LinearGradient(
                  colors: [Color.MeetPR.goldGradientStart, Color.MeetPR.goldGradientEnd],
                  startPoint: .leading, endPoint: .trailing))
              : AnyShapeStyle(Color.MeetPR.borderStrong)
          )
          .frame(width: 51, height: 31)
          .overlay(alignment: configuration.isOn ? .trailing : .leading) {
            Circle().fill(.white).frame(width: 27, height: 27).padding(2)
          }
          .frame(minHeight: MeetPRSpacing.minimumHitTarget)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityRepresentation {
        Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch)
      }
    }
  }
}
