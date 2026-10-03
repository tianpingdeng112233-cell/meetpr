import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct RestTimerExplanationView: View {
  let onAcknowledge: () -> Void
  let onOpenSettings: () -> Void
  private let presentation = RestTimerExplanationPresentation()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
        Text(StudentStrings.localized(.restTimerExplanationView001))
          .font(.MeetPR.display(size: MeetPRFontMetrics.size22))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(StudentStrings.localized(.restTimerExplanationView002))
          .font(.MeetPR.body)
          .foregroundStyle(Color.MeetPR.textSecondary)
        VStack(spacing: MeetPRSpacing.md) {
          ForEach(presentation.rows) { row in
            HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.md) {
              Text(row.condition).font(.MeetPR.body)
              Spacer(minLength: MeetPRSpacing.sm)
              Text(row.duration).font(.MeetPR.monoLabel)
                .fixedSize()
            }
          }
        }
        .padding(MeetPRSpacing.md)
        .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
        Text(StudentStrings.localized(.restTimerExplanationView003))
          .font(.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.textSecondary)
        Button(action: onAcknowledge) {
          Text(StudentStrings.localized(.restTimerExplanationView005))
            .font(.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.ctaText)
            .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.point52)
            .background(Color.MeetPR.ctaBackground, in: .capsule)
        }
        .buttonStyle(PressScaleButtonStyle())
        Button(action: onOpenSettings) {
          Text(StudentStrings.localized(.restExplanationSettings))
            .font(.MeetPR.footnote)
            .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
        }
      }
      .fixedSize(horizontal: false, vertical: true)
      .padding(MeetPRSpacing.lg)
    }
    .background(Color.MeetPR.surfaceElevated)
  }
}
