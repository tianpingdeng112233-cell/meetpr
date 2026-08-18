import DesignSystem
import RepositoryContracts
import SwiftUI

/// 学员页的新学员申请卡(样机 538–546)。
@available(iOS 17.0, macOS 14.0, *)
struct CoachApplicationCard: View {
  let item: CoachBindRequestItem
  let now: Date
  let onAccept: () -> Void
  let onViewProfile: () -> Void
  let onReject: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
      HStack(alignment: .top) {
        Text(item.displayName)
          .font(.MeetPR.display(size: MeetPRFontMetrics.size18))
          .foregroundStyle(Color.MeetPR.textPrimary)

        Spacer(minLength: MeetPRSpacing.space2)

        Text(CoachOnboardingDisplay.waitingText(since: item.submittedAt, now: now))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textTertiary)
      }

      Text(summaryText)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .padding(.top, MeetPRSpacing.point5)

      HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.space1) {
        Text(oneRMText)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .bold))
          .tracking(0.28)
          .foregroundStyle(Color.MeetPR.textPrimary)

        Text("(kg)")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textTertiary)
      }
      .padding(.top, MeetPRSpacing.point7)

      HStack(spacing: MeetPRSpacing.point9) {
        Button(CoachRosterStrings.accept, action: onAccept)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
          .foregroundStyle(Color.MeetPR.inkOnCTAFill)
          .frame(maxWidth: .infinity)
          .padding(.vertical, MeetPRSpacing.space3)
          .background(Color.MeetPR.textPrimary, in: .capsule)
          .buttonStyle(PressScaleButtonStyle(scale: 0.97))

        Button(CoachRosterStrings.viewProfile, action: onViewProfile)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, MeetPRSpacing.space3)
          .overlay {
            Capsule()
              .stroke(Color.MeetPR.borderStrong, lineWidth: MeetPRSpacing.point1)
          }
          .buttonStyle(PressScaleButtonStyle(scale: 0.97))

        Button(action: onReject) {
          Image(systemName: "xmark")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size17, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textTertiary)
            .frame(width: MeetPRSpacing.size46)
            .padding(.vertical, MeetPRSpacing.space3)
            .overlay {
              Capsule()
                .stroke(Color.MeetPR.borderDefault, lineWidth: MeetPRSpacing.point1)
            }
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.97))
        .accessibilityLabel(CoachRosterStrings.reject)
      }
      .padding(.top, MeetPRSpacing.point13)
    }
    .padding(MeetPRSpacing.space4)
    .meetPRCardSurface(.card)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.card)
        .stroke(Color.MeetPR.gold500.opacity(0.35), lineWidth: MeetPRSpacing.point1)
    }
  }

  private var summaryText: String {
    let onboarding = item.onboarding
    let parts = [
      onboarding.gender.map { CoachOnboardingDisplay.genderText($0) },
      CoachOnboardingDisplay.age(
        birthDate: onboarding.birthDate,
        now: now,
        calendar: CoachFeatureCalendar.calendar
      )
      .map(CoachRosterStrings.age),
      onboarding.weightKg
        .map { "\(CoachOnboardingDisplay.decimalText($0)) kg" },
      onboarding.trainingYears
        .map { CoachOnboardingDisplay.trainingYearsText($0) },
    ]
    return parts.compactMap { $0 }.joined(separator: " · ")
  }

  private var oneRMText: String {
    let onboarding = item.onboarding
    let squat = onboarding.squat1RMKg.map(CoachOnboardingDisplay.decimalText) ?? "—"
    let bench = onboarding.bench1RMKg.map(CoachOnboardingDisplay.decimalText) ?? "—"
    let deadlift = onboarding.deadlift1RMKg.map(CoachOnboardingDisplay.decimalText) ?? "—"
    return "S:\(squat)　B:\(bench)　D:\(deadlift)"
  }
}
