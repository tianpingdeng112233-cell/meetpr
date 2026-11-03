import Analytics
import CoreModels
import DesignSystem
import SwiftUI

struct DashboardFirstPlanCard: View {
  let plan: BindFirstRun.FirstPlan
  let coachName: String
  let isStarting: Bool
  let isVisible: Bool
  let onStart: () -> Void
  let onDismiss: () -> Void
  @State private var viewedPlanID: UUID?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 0) {
        VStack(alignment: .leading, spacing: 6) {
          Text(StudentStrings.localized(.firstPlanLabel))
            .font(.caption)
            .foregroundStyle(Color.MeetPR.goldText)
          Text(StudentStrings.replacing(.firstPlanTitle, values: [coachName]))
            .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Button(action: onDismiss) {
          Image(systemName: "xmark")
            .frame(width: 44, height: 44)
            .contentShape(.rect)
        }
        .accessibilityLabel(StudentStrings.localized(.firstPlanDismiss))
        .accessibilityIdentifier("dashboard.firstPlan.dismiss")
      }
      Text(
        StudentStrings.replacing(
          .firstPlanSummary, values: [plan.planWeeks.formatted(), plan.dayCount.formatted()])
      )
      .font(.footnote.monospaced())
      .foregroundStyle(Color.MeetPR.textSecondary)
      Button(action: onStart) {
        Label(StudentStrings.localized(.firstPlanStart), systemImage: "play.fill")
          .font(.headline)
          .foregroundStyle(Color.MeetPR.surfaceCard)
          .frame(maxWidth: .infinity, minHeight: 50)
          .background(Color.MeetPR.textPrimary, in: .capsule)
          .contentShape(.capsule)
      }
      .disabled(isStarting)
      .accessibilityIdentifier("dashboard.firstPlan.start")
    }
    .foregroundStyle(Color.MeetPR.textPrimary)
    .padding(18)
    .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.card)
        .stroke(Color.MeetPR.gold500, lineWidth: 1.5)
    }
    .task(id: isVisible ? plan.id : nil) {
      guard isVisible, viewedPlanID != plan.id else { return }
      viewedPlanID = plan.id
      Analytics.shared.track(.firstPlanViewed, props: ["plan_id": .id(plan.id)])
    }
  }
}

struct DashboardNewStudentWaitingCard: View {
  let coachName: String
  let showsMeetDate: Bool
  let onMessageCoach: () -> Void
  let onOpenProfile: () -> Void
  let onEditMeet: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(StudentStrings.replacing(.firstRunWaitingTitle, values: [coachName]))
        .font(.headline)
      Text(StudentStrings.localized(.firstRunWaitingBody))
        .font(.subheadline)
        .foregroundStyle(Color.MeetPR.textSecondary)
      Button(action: onMessageCoach) {
        Text(StudentStrings.localized(.firstRunMessageCoach))
          .font(.subheadline.bold())
          .frame(maxWidth: .infinity, minHeight: 46)
          .overlay { Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1) }
          .contentShape(.capsule)
      }
      Divider()
      Text(StudentStrings.localized(.firstRunWhileWaiting))
        .font(.caption)
        .foregroundStyle(Color.MeetPR.textSecondary)
      FirstRunGuidanceRow(
        title: .firstRunProfile, detail: .firstRunProfileBody, action: onOpenProfile)
      if showsMeetDate {
        FirstRunGuidanceRow(title: .firstRunMeet, detail: .firstRunMeetBody, action: onEditMeet)
      }
    }
    .foregroundStyle(Color.MeetPR.textPrimary)
    .padding(20)
    .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
    .accessibilityIdentifier("dashboard.firstRun.waiting")
  }
}

private struct FirstRunGuidanceRow: View {
  let title: StudentStrings.Key
  let detail: StudentStrings.Key
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(StudentStrings.localized(title)).font(.subheadline.bold())
          Text(StudentStrings.localized(detail))
            .font(.caption)
            .foregroundStyle(Color.MeetPR.textSecondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
      }
      .frame(minHeight: 44)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}
