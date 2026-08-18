import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct PlanningDraftSection: View {
  let rows: [PlanningDraftRowModel]
  let onContinue: (PlanningDraftRowModel) -> Void

  var body: some View {
    PlanningWorkspaceSection(title: PlanningWorkspaceStrings.text("coach.workspace.section.drafts"))
    {
      ForEach(rows) { row in
        PlanningWorkspaceActionRow(
          title: row.student.displayName,
          summary: row.summary,
          badge: PlanningWorkspaceBadge(
            status: .pending,
            title: PlanningWorkspaceStrings.text("coach.workspace.badge.inProgress")),
          actionTitle: PlanningWorkspaceStrings.text("coach.workspace.action.continue"),
          avatarSize: 42
        ) {
          onContinue(row)
        }
      }
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct PlanningNeedsSection: View {
  let rows: [PlanningNeededRowModel]
  let onPlan: (PlanningNeededRowModel) -> Void

  var body: some View {
    PlanningWorkspaceSection(title: PlanningWorkspaceStrings.text("coach.workspace.section.needs"))
    {
      ForEach(rows) { row in
        PlanningWorkspaceActionRow(
          title: row.student.displayName,
          summary: row.summary,
          badge: PlanningWorkspaceBadge.needsPlanning(row.reason),
          actionTitle: PlanningWorkspaceStrings.text("coach.workspace.action.plan"),
          avatarSize: 42
        ) {
          onPlan(row)
        }
      }
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct PlanningRecentPublishedSection: View {
  let rows: [PlanningPublishedRowModel]
  let context: CoachStudentDetailContext

  var body: some View {
    PlanningWorkspaceSection(title: PlanningWorkspaceStrings.text("coach.workspace.section.recent"))
    {
      ForEach(rows) { row in
        NavigationLink {
          StudentDetailView(summary: row.student, context: context)
        } label: {
          PlanningWorkspacePublishedRow(row: row)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct PlanningWorkspaceSection<Content: View>: View {
  let title: String
  private let content: Content

  init(
    title: String,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Eyebrow(title)
      content
    }
  }
}

private struct PlanningWorkspaceBadge {
  let status: StatusBadge.Status
  let title: String

  static func needsPlanning(_ reason: PlanningPlanNeedReason) -> PlanningWorkspaceBadge {
    switch reason {
    case .noCurrentPlan:
      PlanningWorkspaceBadge(
        status: .pending, title: PlanningWorkspaceStrings.text("coach.workspace.badge.noPlan"))
    case .ended:
      PlanningWorkspaceBadge(
        status: .overdue, title: PlanningWorkspaceStrings.text("coach.workspace.badge.ended"))
    case .endsThisWeek:
      PlanningWorkspaceBadge(
        status: .overdue, title: PlanningWorkspaceStrings.text("coach.workspace.badge.endsThisWeek")
      )
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct PlanningWorkspaceActionRow: View {
  let title: String
  let summary: String
  let badge: PlanningWorkspaceBadge
  let actionTitle: String
  let avatarSize: CGFloat
  let action: () -> Void

  var body: some View {
    Card(accessibilityLabel: title) {
      HStack(alignment: .center, spacing: MeetPRSpacing.base) {
        InitialAvatar(title, size: avatarSize)
        rowText
        Spacer(minLength: MeetPRSpacing.sm)
        actionButton
      }
    }
  }

  private var rowText: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
        Text(title)
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(1)

        StatusBadge(status: badge.status, title: badge.title)
      }

      Text(summary)
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var actionButton: some View {
    PrimaryButton(actionTitle, action: action)
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct PlanningWorkspacePublishedRow: View {
  let row: PlanningPublishedRowModel

  var body: some View {
    Card(accessibilityLabel: row.student.displayName) {
      HStack(alignment: .center, spacing: MeetPRSpacing.base) {
        InitialAvatar(row.student.displayName, size: 42)
        VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
          HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
            Text(row.student.displayName)
              .font(Font.MeetPR.bodyEmphasis)
              .foregroundStyle(Color.MeetPR.fgPrimary)
              .lineLimit(1)

            StatusBadge(
              status: .completed,
              title: PlanningWorkspaceStrings.text("coach.workspace.badge.published"))
          }

          Text(
            PlanningWorkspaceStrings.replacing(
              "coach.workspace.publishedRow", ["summary": row.summary, "date": dateText])
          )
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
          .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Spacer(minLength: MeetPRSpacing.sm)
        PlanningWorkspaceActionPill(
          title: PlanningWorkspaceStrings.text("coach.workspace.action.view"))
      }
    }
  }

  private var dateText: String {
    PlanningWorkspaceSummary.proxyDateText(row.proxyPublishedAt)
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct PlanningWorkspaceActionPill: View {
  let title: String

  var body: some View {
    HStack(spacing: MeetPRSpacing.xs) {
      Text(title)
      Image(systemName: "chevron.right")
        .font(.system(size: 12, weight: .semibold))
    }
    .font(Font.MeetPR.bodyEmphasis)
    .foregroundStyle(.white)
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.vertical, MeetPRSpacing.sm)
    .background(Color.MeetPR.brandRed)
    .clipShape(.capsule)
  }
}
