import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct PlanningDraftSection: View {
  let rows: [PlanningDraftRowModel]
  let onContinue: (PlanningDraftRowModel) -> Void

  var body: some View {
    PlanningWorkspaceSection(title: "进行中草稿") {
      ForEach(rows) { row in
        PlanningWorkspaceActionRow(
          title: row.student.displayName,
          summary: row.summary,
          actionTitle: "继续",
          systemImage: "arrow.right.circle.fill"
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
    PlanningWorkspaceSection(title: "谁需要排计划") {
      ForEach(rows) { row in
        PlanningWorkspaceActionRow(
          title: row.student.displayName,
          summary: row.summary,
          actionTitle: "排",
          systemImage: "calendar.badge.plus"
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
    PlanningWorkspaceSection(title: "最近发布") {
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
      Text(title)
        .font(Font.MeetPR.headline)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      content
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct PlanningWorkspaceActionRow: View {
  let title: String
  let summary: String
  let actionTitle: String
  let systemImage: String
  let action: () -> Void

  var body: some View {
    Card(accessibilityLabel: title) {
      HStack(alignment: .center, spacing: MeetPRSpacing.base) {
        rowText
        Spacer(minLength: MeetPRSpacing.sm)
        actionButton
      }
    }
  }

  private var rowText: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      Text(title)
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .lineLimit(1)
      Text(summary)
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)
        .lineLimit(2)
    }
  }

  private var actionButton: some View {
    Button(action: action) {
      Label(actionTitle, systemImage: systemImage)
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(actionTitle)
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct PlanningWorkspacePublishedRow: View {
  let row: PlanningPublishedRowModel

  var body: some View {
    Card(accessibilityLabel: row.student.displayName) {
      HStack(alignment: .center, spacing: MeetPRSpacing.base) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
          Text(row.student.displayName)
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .lineLimit(1)
          Text(row.summary)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
            .lineLimit(1)
        }
        Spacer(minLength: MeetPRSpacing.sm)
        Text(dateText)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgTertiary)
        Image(systemName: "chevron.right")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
    }
  }

  private var dateText: String {
    "\(PlanningWorkspaceSummary.proxyDateText(row.proxyPublishedAt))发"
  }
}
