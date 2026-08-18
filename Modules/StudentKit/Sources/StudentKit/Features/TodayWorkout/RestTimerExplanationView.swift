import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct RestTimerExplanationView: View {
  let onAcknowledge: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      Image(systemName: "timer")
        .font(.largeTitle)
        .foregroundStyle(Color.MeetPR.gold500)

      Text(StudentStrings.localized(.restTimerExplanationView001))
        .font(.MeetPR.display(size: MeetPRFontMetrics.size22))
        .foregroundStyle(Color.MeetPR.textPrimary)

      explanationRow(
        icon: "gauge.with.dots.needle.33percent",
        text: StudentStrings.localized(.restTimerExplanationView002)
      )
      explanationRow(
        icon: "person.fill.checkmark", text: StudentStrings.localized(.restTimerExplanationView003))
      explanationRow(
        icon: "gearshape", text: StudentStrings.localized(.restTimerExplanationView004))

      Button(action: onAcknowledge) {
        Text(StudentStrings.localized(.restTimerExplanationView005))
          .font(.MeetPR.display(size: MeetPRFontMetrics.size16))
          .foregroundStyle(Color.MeetPR.ctaText)
          .frame(maxWidth: .infinity)
          .frame(height: MeetPRSpacing.point52)
          .background(Color.MeetPR.ctaBackground)
          .clipShape(.capsule)
      }
      .buttonStyle(PressScaleButtonStyle())
      .padding(.top, MeetPRSpacing.xs)
    }
    .padding(MeetPRSpacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surfaceElevated)
  }

  private func explanationRow(icon: String, text: String) -> some View {
    HStack(alignment: .top, spacing: MeetPRSpacing.sm) {
      Image(systemName: icon)
        .foregroundStyle(Color.MeetPR.textMuted)
        .frame(width: 24)
      Text(text)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
