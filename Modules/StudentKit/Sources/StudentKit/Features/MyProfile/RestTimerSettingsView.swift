import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct RestTimerSettingsView: View {
  @Binding var preference: StudentRestTimerPreference

  var body: some View {
    Form {
      Section {
        Picker("默认行为", selection: modeBinding) {
          Text("自动(按 RPE)").tag(RestTimerPreferenceMode.automatic)
          Text("固定时长").tag(RestTimerPreferenceMode.fixed)
        }
        .pickerStyle(.segmented)
      } footer: {
        Text("教练在计划中指定的休息时长始终优先。此设置只改变没有教练设定时的默认行为。")
      }

      if case .fixed = preference {
        Section("固定时长") {
          Picker("固定时长", selection: fixedSecondsBinding) {
            ForEach(Self.fixedDurationOptions, id: \.self) { seconds in
              Text(Self.durationText(seconds)).tag(seconds)
            }
          }
          #if os(iOS)
            .pickerStyle(.wheel)
          #else
            .pickerStyle(.menu)
          #endif
          .labelsHidden()
          .frame(maxWidth: .infinity)
        }
      }

      Section("自动规则") {
        LabeledContent("RPE 低于 7", value: "2 分钟")
        LabeledContent("RPE 7 至 9 以下", value: "3 分钟")
        LabeledContent("RPE 9 及以上", value: "4 分钟")
      }
    }
    .scrollContentBackground(.hidden)
    .background(Color.MeetPR.bgBase)
    .tint(Color.MeetPR.gold500)
    .navigationTitle("组间休息")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
  }

  private var modeBinding: Binding<RestTimerPreferenceMode> {
    Binding(
      get: { preference.fixedSeconds == nil ? .automatic : .fixed },
      set: { mode in
        preference =
          mode == .automatic
          ? .automatic
          : .fixed(seconds: StudentRestTimerPreference.defaultFixedSeconds)
      }
    )
  }

  private var fixedSecondsBinding: Binding<Int> {
    Binding(
      get: { preference.fixedSeconds ?? StudentRestTimerPreference.defaultFixedSeconds },
      set: { preference = .fixed(seconds: $0) }
    )
  }

  private static let fixedDurationOptions = Array(
    stride(
      from: StudentRestTimerPreference.fixedRange.lowerBound,
      through: StudentRestTimerPreference.fixedRange.upperBound,
      by: StudentRestTimerPreference.fixedStep
    )
  )

  private static func durationText(_ seconds: Int) -> String {
    Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
  }
}

private enum RestTimerPreferenceMode: Hashable {
  case automatic
  case fixed
}
