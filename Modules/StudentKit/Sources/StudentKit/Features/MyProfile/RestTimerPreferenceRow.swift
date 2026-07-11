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
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("组间休息")
            .font(.system(size: 14))
            .foregroundStyle(Color.MeetPR.fgTertiary)
          Text(summary)
            .font(.system(size: 17))
            .foregroundStyle(Color.MeetPR.fgPrimary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: 15))
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
      .padding(16)
      .frame(minHeight: 64)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
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
