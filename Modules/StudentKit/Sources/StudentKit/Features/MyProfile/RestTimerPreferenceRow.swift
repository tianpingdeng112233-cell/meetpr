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
      MyProfileValueRow(label: "组间休息", value: summary)
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
    guard let seconds = preference.fixedSeconds else { return "自动 (按 RPE)" }
    return "固定 \(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))"
  }
}
