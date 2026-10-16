import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct TrainingSessionTimerChip: View {
  let seconds: Int

  var body: some View {
    HStack(spacing: 5) {
      Text("●")
        .foregroundStyle(Color.MeetPR.brandRed)
      Text(TrainingSessionTimer.text(seconds: seconds))
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .monospacedDigit()
    }
    .font(.system(size: 12, weight: .semibold, design: .monospaced))
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(Color.MeetPR.surface2)
    .clipShape(.capsule)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("训练计时 \(TrainingSessionTimer.text(seconds: seconds))")
  }
}
