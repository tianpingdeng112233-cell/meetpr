import DesignSystem
import RepositoryContracts
import SwiftUI

/// Settings is independent of profile availability; also retains the existing fallback seam.
struct MyProfileFallbackRows: View {
  let studentID: UUID
  let plans: any StudentPlanRepository
  let account: (any AccountRepository)?
  let logs: (any StudentTrainingLogRepository)?
  let restTimerSettings: any StudentRestTimerSettingsStoring
  let trainingReminderServices: TrainingReminderServices
  let onLogout: (@MainActor () async -> Void)?
  var recommendedWeekdays: Set<TrainingReminderWeekday>?

  var body: some View {
    ProfileSettingsHeading(text: StudentStrings.localized(.profilePreferences))
    MyProfileGroupCard {
      AppearancePreferenceRow()
      MyProfileDivider()
      RestTimerPreferenceRow(studentID: studentID, settings: restTimerSettings)
      MyProfileDivider()
      TrainingReminderPreferenceRow(
        studentID: studentID, services: trainingReminderServices, plans: plans,
        recommendedWeekdays: recommendedWeekdays)
    }
    if let account, let logs {
      ProfileSettingsHeading(text: StudentStrings.localized(.profileAccount))
      AccountSecuritySection(
        studentID: studentID, account: account, logs: logs, plans: plans, onLogout: onLogout)
    }
    if let onLogout { ProfileSignOutButton(onLogout: onLogout) }
  }
}

private struct ProfileSettingsHeading: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
      .foregroundStyle(Color.MeetPR.textMuted)
      .padding(.leading, MeetPRSpacing.xs)
  }
}

struct ProfileSignOutButton: View {
  let onLogout: @MainActor () async -> Void

  var body: some View {
    Button {
      Task { await onLogout() }
    } label: {
      Text(StudentStrings.localized(.myProfileView013))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.point52)
        .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.card)
            .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
  }
}
