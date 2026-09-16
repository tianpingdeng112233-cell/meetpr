import SwiftUI

struct ExerciseCardHeader: View {
  let exercise: String
  let meta: String
  let allRecorded: Bool
  let progressText: String
  let summaryText: String
  let open: Bool
  let rollProgress: CGFloat
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: MeetPRSpacing.point11) {
        RoundedRectangle(cornerRadius: MeetPRRadius.micro)
          .fill(allRecorded ? Color.MeetPR.success : Color.MeetPR.gold500)
          .frame(width: MeetPRSpacing.point3)
          .frame(
            minHeight: open
              ? ExerciseCardContract.expandedBarMinimumHeight
              : ExerciseCardContract.collapsedBarMinimumHeight
          )
          .frame(maxHeight: .infinity)

        VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
          Text(exercise)
            .font(
              .MeetPR.display(
                size: open
                  ? ExerciseCardContract.expandedNameSize
                  : ExerciseCardContract.collapsedNameSize
              )
            )
            .foregroundStyle(
              open
                ? Color.MeetPR.textPrimary
                : Color.MeetPR.textSecondary
            )
            .lineLimit(1)

          if open {
            Text(meta)
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
              .foregroundStyle(Color.MeetPR.textMuted)
              .lineLimit(1)
              .modifier(RollUpMetaModifier(progress: rollProgress))
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Text(open ? progressText : summaryText)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
          .tracking(open ? 0 : -0.2)
          .foregroundStyle(allRecorded ? Color.MeetPR.success : Color.MeetPR.textDim)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
          .allowsTightening(true)
          .layoutPriority(1)

        Text("▾")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textMuted)
          .rotationEffect(
            .degrees(open ? 0 : ExerciseCardContract.collapsedCaretRotation)
          )
      }
      .padding(.horizontal, MeetPRSpacing.space4)
      .padding(.vertical, MeetPRSpacing.space3)
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      .contentShape(.rect)
    }
    .accessibilityLabel("\(exercise)，\(open ? progressText : summaryText)")
    .accessibilityValue(
      open ? DesignSystemStrings.expanded : DesignSystemStrings.collapsed
    )
  }
}
