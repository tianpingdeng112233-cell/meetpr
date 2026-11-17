import DesignSystem
import SwiftUI

struct RestRingSettingsDisk: View {
  @Binding var mainSeconds: Int
  @Binding var accessorySeconds: Int
  @Binding var vibration: Bool
  @Binding var sound: Bool

  var body: some View {
    VStack(spacing: 16) {
      Text(StudentStrings.localized(.restRingSettings))
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(Color.MeetPR.textSecondary)
      HStack(spacing: 16) {
        RestRingDurationWheel(title: .restRingMain, seconds: $mainSeconds)
        RestRingDurationWheel(title: .restRingAccessory, seconds: $accessorySeconds)
      }
      HStack(spacing: 40) {
        RestRingAlertToggle(
          title: .restRingVibration, icon: "iphone.radiowaves.left.and.right",
          enabled: $vibration)
        RestRingAlertToggle(title: .restRingSound, icon: "speaker.wave.2", enabled: $sound)
      }
    }
    .frame(width: 340, height: 340)
    .background(Color.MeetPR.surface2, in: .circle)
    .overlay { Circle().strokeBorder(Color.MeetPR.borderStrong, lineWidth: 1) }
    .accessibilityIdentifier("restRing.settings")
  }
}

private struct RestRingDurationWheel: View {
  let title: StudentStrings.Key
  @Binding var seconds: Int

  var body: some View {
    VStack(spacing: 4) {
      Text(StudentStrings.localized(title))
        .font(.system(size: 13))
        .foregroundStyle(Color.MeetPR.textSecondary)
      Picker(StudentStrings.localized(title), selection: $seconds) {
        ForEach(Array(stride(from: 30, through: 600, by: 15)), id: \.self) { value in
          Text(Duration.seconds(value).formatted(.time(pattern: .minuteSecond)))
            .font(.system(size: 22, weight: .bold, design: .monospaced))
            .tag(value)
        }
      }
      #if os(iOS)
        .pickerStyle(.wheel)
      #endif
      .frame(width: 112, height: 102)
      .clipped()
    }
  }
}

private struct RestRingAlertToggle: View {
  let title: StudentStrings.Key
  let icon: String
  @Binding var enabled: Bool

  var body: some View {
    VStack(spacing: 6) {
      Button {
        enabled.toggle()
      } label: {
        Image(systemName: icon)
          .font(.system(size: 20))
          .foregroundStyle(enabled ? Color.MeetPR.inkOnGold : Color.MeetPR.textSecondary)
          .frame(width: 48, height: 48)
          .background(enabled ? Color.MeetPR.gold500 : Color.MeetPR.surface3, in: .circle)
          .overlay {
            if !enabled { Circle().strokeBorder(Color.MeetPR.borderStrong, lineWidth: 1) }
          }
      }
      .buttonStyle(.plain)
      .accessibilityLabel(StudentStrings.localized(title))
      .accessibilityValue(StudentStrings.localized(enabled ? .restRingOn : .restRingOff))
      let status = StudentStrings.localized(enabled ? .restRingOn : .restRingOff)
      Text("\(StudentStrings.localized(title)) · \(status)")
        .font(.system(size: 11))
        .foregroundStyle(Color.MeetPR.textSecondary)
    }
  }
}
