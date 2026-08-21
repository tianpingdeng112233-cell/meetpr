import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct PlanningStudentHeaderView: View {
  let student: CoachStudentSummary
  /// Onboarding profile of the selected student (David 2026-06-14): the
  /// expanded bar shows the planning-relevant info, not just id + status.
  var profile: OnboardingProfile?
  @State private var isExpanded = false

  var body: some View {
    Card(accessibilityLabel: "Selected student") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
          Text(student.displayName)
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.fgPrimary)

          Text(statusSummary)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
            .lineLimit(1)

          Spacer()

          Button(isExpanded ? CoachPlanningStrings.collapse : CoachPlanningStrings.expand) {
            isExpanded.toggle()
          }
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.brandRed)
        }

        if isExpanded {
          expandedDetail
        }
      }
    }
  }

  @ViewBuilder
  private var expandedDetail: some View {
    if let profile {
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        ForEach(detailRows(profile), id: \.label) { row in
          HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
            Text(row.label)
              .foregroundStyle(Color.MeetPR.fgTertiary)
              .frame(width: 72, alignment: .leading)
            Text(row.value)
              .foregroundStyle(Color.MeetPR.fgSecondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
      .font(Font.MeetPR.footnote)
    } else {
      Text(CoachPlanningStrings.profileUnavailable)
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgTertiary)
    }
  }

  private func detailRows(_ profile: OnboardingProfile) -> [DetailRow] {
    var rows: [DetailRow] = []
    if let basics = StudentProfileSummary.basics(profile) {
      rows.append(DetailRow(label: CoachPlanningStrings.basic, value: basics))
    }
    if let oneRMs = StudentProfileSummary.oneRMs(profile) {
      rows.append(DetailRow(label: "1RM", value: oneRMs))
    }
    if let days = StudentProfileSummary.trainingDays(profile) {
      rows.append(DetailRow(label: CoachPlanningStrings.trainingDays, value: days))
    }
    if let gym = StudentProfileSummary.gym(profile) {
      rows.append(DetailRow(label: CoachPlanningStrings.venue, value: gym))
    }
    if let injuries = StudentProfileSummary.injuries(profile) {
      rows.append(DetailRow(label: CoachPlanningStrings.injuries, value: injuries))
    }
    if let meet = StudentProfileSummary.competition(profile) {
      rows.append(DetailRow(label: CoachPlanningStrings.competition, value: meet))
    }
    if let note = StudentProfileSummary.noteToCoach(profile) {
      rows.append(DetailRow(label: CoachPlanningStrings.note, value: note))
    }
    if rows.isEmpty {
      rows.append(
        DetailRow(
          label: CoachPlanningStrings.profile,
          value: CoachPlanningStrings.profileNotCompleted
        )
      )
    }
    return rows
  }

  private var statusSummary: String {
    switch student.status {
    case .inEvaluation(let days, let hours):
      CoachPlanningStrings.evaluationRemaining(days: days, hours: hours)
    case .active:
      CoachPlanningStrings.active
    case .abnormal(let reason):
      PlanningDisplay.abnormalReason(reason)
    }
  }
}

private struct DetailRow {
  let label: String
  let value: String
}
