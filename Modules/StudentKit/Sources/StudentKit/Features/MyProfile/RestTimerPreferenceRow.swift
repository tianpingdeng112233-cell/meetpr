import DesignSystem
import SwiftUI

/// Self-contained profile row for the rest-timer preference: owns its state
/// and writes through to the device-local store on change, so both the loaded
/// profile card and the empty/failed fallback can drop it in without plumbing.
@available(iOS 17.0, macOS 14.0, *)
struct RestTimerPreferenceRow: View {
  private let studentID: UUID
  private let settings: any StudentRestTimerSettingsStoring
  @State private var preference: StudentRestTimerPreference

  init(studentID: UUID, settings: any StudentRestTimerSettingsStoring) {
    self.studentID = studentID
    self.settings = settings
    self._preference = State(initialValue: settings.preference(for: studentID))
  }

  var body: some View {
    NavigationLink {
      RestTimerSettingsView(preference: preferenceBinding)
    } label: {
      HStack(spacing: MeetPRSpacing.space3) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
          Text("组间休息")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size14))
            .foregroundStyle(Color.MeetPR.textTertiary)
          Text(summary)
            .font(.MeetPR.system(size: MeetPRFontMetrics.size17))
            .foregroundStyle(Color.MeetPR.textPrimary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size15))
          .foregroundStyle(Color.MeetPR.textTertiary)
      }
      .padding(MeetPRSpacing.space4)
      .frame(minHeight: 64)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  private var preferenceBinding: Binding<StudentRestTimerPreference> {
    Binding(
      get: { preference },
      set: { newValue in
        preference = newValue
        settings.setPreference(newValue, for: studentID)
      }
    )
  }

  private var summary: String {
    guard let seconds = preference.fixedSeconds else { return "自动(按 RPE)" }
    return "固定 \(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))"
  }
}
