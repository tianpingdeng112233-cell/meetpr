import DesignSystem
import SwiftUI

struct TrainingEmptyStateView: View {
  let presentation: TrainingEmptyStatePresentation
  let coachName: String
  let showsCoach: Bool
  let onCoach: () -> Void
  let onProfile: () -> Void
  let onMeet: () -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.space4) {
      Image(systemName: "calendar")
        .font(.title2)
        .foregroundStyle(Color.MeetPR.goldText)
        .frame(width: 64, height: 64)
        .background(Color.MeetPR.goldText.opacity(0.12), in: .circle)
      Text(presentation.title(coach: coachName))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size20, weight: .bold))
      Text(presentation.detail(coach: coachName))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
      if showsCoach {
        Button(action: onCoach) {
          Label(StudentStrings.localized(.trainingMessageCoach), systemImage: "bubble.left")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: 14))
            .overlay {
              RoundedRectangle(cornerRadius: 14).stroke(Color.MeetPR.borderSubtle, lineWidth: 1)
            }
        }
        .accessibilityIdentifier("training.empty.coach")
      }
      if presentation == .firstPlan {
        Text(StudentStrings.localized(.trainingWhileWaiting))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, MeetPRSpacing.space4)
        VStack(spacing: 0) {
          TrainingWaitingLink(title: .trainingCompleteProfile, action: onProfile)
          Divider()
          TrainingWaitingLink(title: .trainingCompleteMeet, action: onMeet)
        }
        .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: 14))
      }
    }
    .multilineTextAlignment(.center)
    .foregroundStyle(Color.MeetPR.textPrimary)
    .padding(.top, MeetPRSpacing.point40)
    .frame(maxWidth: .infinity)
  }
}

private struct TrainingWaitingLink: View {
  let title: StudentStrings.Key
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        Text(StudentStrings.localized(title))
        Spacer()
        Image(systemName: "chevron.right").foregroundStyle(Color.MeetPR.textSecondary)
      }
      .padding(MeetPRSpacing.space4)
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      .contentShape(.rect)
    }
  }
}
