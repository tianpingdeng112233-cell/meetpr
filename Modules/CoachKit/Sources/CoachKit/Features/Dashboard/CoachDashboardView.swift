// swiftlint:disable file_length
import ChatUI
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachDashboardView: View {
  private let context: CoachStudentDetailContext
  private let now: Date
  private let rows: [StudentRosterRowModel]
  private let videos: [PendingVideoItem]
  private let applications: [CoachBindRequestItem]
  private let conversations: [ChatConversation]
  private let acceptedStudentName: String?
  private let onOpenMessages: @MainActor () -> Void
  private let onOpenRoster: @MainActor () -> Void
  private let onEvaluationCompleted: @MainActor (UUID) -> Void
  private let chat: CoachChatContext?

  @State private var selectedStudent: StudentRosterRowModel?
  @State private var conversationOpener: CoachConversationOpener

  init(
    context: CoachStudentDetailContext,
    now: Date,
    rows: [StudentRosterRowModel] = [],
    videos: [PendingVideoItem] = [],
    applications: [CoachBindRequestItem] = [],
    conversations: [ChatConversation] = [],
    acceptedStudentName: String? = nil,
    onOpenMessages: @escaping @MainActor () -> Void = {},
    onOpenRoster: @escaping @MainActor () -> Void = {},
    onEvaluationCompleted: @escaping @MainActor (UUID) -> Void = { _ in },
    chat: CoachChatContext? = nil
  ) {
    self.context = context
    self.now = now
    self.rows = rows
    self.videos = videos
    self.applications = applications
    self.conversations = conversations
    self.acceptedStudentName = acceptedStudentName
    self.onOpenMessages = onOpenMessages
    self.onOpenRoster = onOpenRoster
    self.onEvaluationCompleted = onEvaluationCompleted
    self.chat = chat
    _conversationOpener = State(initialValue: CoachConversationOpener(chat: chat))
  }

  var body: some View {
    let todoItems = CoachTodayTodoList.makeItems(
      videos: videos,
      conversations: conversations,
      rosterRows: rows,
      applications: applications,
      now: now
    )
    let weekSummary = CoachWeekOverview.makeSummary(rows: rows, now: now)

    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.point15) {
          CoachTodayHeader(date: now, todoCount: todoItems.count)

          Text(CoachTodayStrings.orderedByHandling)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textTertiary)

          if todoItems.isEmpty {
            CoachTodayEmptyState()
          } else {
            CoachTodoCard(items: todoItems, onSelect: handleTodo)
          }

          if let acceptedStudentName {
            CoachAcceptedStudentBanner(studentName: acceptedStudentName)
          }

          Text(CoachTodayStrings.weekOverview)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textTertiary)
            .padding(.top, MeetPRSpacing.point2)

          CoachWeekOverviewCard(
            summary: weekSummary,
            onSelectStudent: { studentID in
              selectedStudent = rows.first { $0.id == studentID }
            },
            onViewAll: onOpenRoster
          )
        }
        .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        .padding(.top, MeetPRSpacing.point6)
        .padding(.bottom, MeetPRSpacing.point28)
      }
      .scrollIndicators(.hidden)
      .background(Color.MeetPR.bgBase)
      .hideNavigationBar()
      .navigationDestination(item: $selectedStudent) { row in
        StudentDetailView(
          summary: row.student,
          context: context,
          onEvaluationCompleted: { onEvaluationCompleted(row.id) }
        )
      }
      .navigationDestination(item: conversationDestinationBinding) { conversation in
        if let chat {
          CoachConversationDestination(
            conversationID: conversation.id,
            chat: chat
          )
        }
      }
    }
    .alert(
      CoachStrings.unableToOpenConversation,
      isPresented: conversationErrorBinding
    ) {
      Button(CoachStrings.confirmation, role: .cancel) {
        conversationOpener.dismissError()
      }
    }
  }

  private func handleTodo(_ destination: CoachTodayTodoList.Destination) {
    switch destination {
    case .messages:
      onOpenMessages()
    case .students:
      onOpenRoster()
    case .studentChat(let studentID):
      Task {
        await conversationOpener.openConversation(withOtherParty: studentID)
      }
    }
  }

  private var conversationDestinationBinding: Binding<ChatConversation?> {
    Binding(
      get: { conversationOpener.destination },
      set: { destination in
        if destination == nil {
          conversationOpener.dismissDestination()
        }
      }
    )
  }

  private var conversationErrorBinding: Binding<Bool> {
    Binding(
      get: { conversationOpener.errorMessage != nil },
      set: { isPresented in
        if !isPresented {
          conversationOpener.dismissError()
        }
      }
    )
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct CoachTodayHeader: View {
  let date: Date
  let todoCount: Int

  var body: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
        Text(CoachTodayFormatting.dateText(date))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .tracking(0.72)
          .foregroundStyle(Color.MeetPR.textTertiary)

        Text(CoachShellStrings.today)
          .font(.MeetPR.display(size: MeetPRFontMetrics.size38))
          .foregroundStyle(Color.MeetPR.textPrimary)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: MeetPRSpacing.point2) {
        Text(CoachTodayStrings.todo)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textTertiary)

        Text(todoCount.formatted())
          .font(.MeetPR.display(size: MeetPRFontMetrics.size28))
          .foregroundStyle(Color.MeetPR.textPrimary)
      }
    }
  }

}

@available(iOS 17.0, macOS 14.0, *)
private struct CoachTodoCard: View {
  let items: [CoachTodayTodoList.Item]
  let onSelect: (CoachTodayTodoList.Destination) -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      ForEach(items.indices, id: \.self) { index in
        let item = items[index]
        Button {
          onSelect(item.destination)
        } label: {
          CoachTodoRow(item: item, showsTopBorder: index > 0)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.97))
      }
    }
    .meetPRCardSurface(.card)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct CoachTodoRow: View {
  let item: CoachTodayTodoList.Item
  let showsTopBorder: Bool

  var body: some View {
    HStack(spacing: MeetPRSpacing.point11) {
      Circle()
        .fill(dotColor)
        .frame(width: MeetPRSpacing.point7, height: MeetPRSpacing.point7)

      VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
        Text(item.title)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)

        Text(item.subtitle)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Text(item.tag)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .semibold))
        .foregroundStyle(dotColor)

      Image(systemName: "chevron.right")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size16, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textDisabled)
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point14)
    .contentShape(.rect)
    .overlay(alignment: .top) {
      if showsTopBorder {
        Rectangle()
          .fill(Color.MeetPR.borderDefault)
          .frame(height: MeetPRSpacing.point1)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var dotColor: Color {
    switch item.dot {
    case .gold: Color.MeetPR.gold500
    case .danger: Color.MeetPR.danger
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct CoachTodayEmptyState: View {
  var body: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      Image(systemName: "checkmark")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size24, weight: .semibold))
        .foregroundStyle(Color.MeetPR.success)
        .frame(width: MeetPRSpacing.point52, height: MeetPRSpacing.point52)
        .meetPRCardSurface(.card)
        .clipShape(.circle)
        .padding(.bottom, MeetPRSpacing.point14)

      Text(CoachTodayStrings.allDone)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)

      Text(CoachTodayStrings.allDoneSubtitle)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textDisabled)
        .padding(.top, MeetPRSpacing.point5)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, MeetPRSpacing.point40)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct CoachAcceptedStudentBanner: View {
  let studentName: String

  var body: some View {
    HStack(spacing: MeetPRSpacing.point10) {
      Image(systemName: "checkmark")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size18, weight: .bold))
        .foregroundStyle(Color.MeetPR.success)

      Text(CoachTodayStrings.acceptedStudent(studentName))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
        .foregroundStyle(Color.MeetPR.success)

      Spacer(minLength: MeetPRSpacing.zero)
    }
    .padding(.horizontal, 17)
    .padding(.vertical, MeetPRSpacing.point15)
    .meetPRCardSurface(.card)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.card)
        .stroke(Color.MeetPR.success.opacity(0.3), lineWidth: MeetPRSpacing.point1)
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct CoachWeekOverviewCard: View {
  let summary: CoachWeekOverview.Summary
  let onSelectStudent: (UUID) -> Void
  let onViewAll: () -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.space3) {
      if summary.planned > 0 {
        summaryHeader
        legendBars
        legendLabels

        Rectangle()
          .fill(Color.MeetPR.borderHairline)
          .frame(height: MeetPRSpacing.point1)

        weekdayHeader

        ForEach(summary.rows) { row in
          Button {
            onSelectStudent(row.studentID)
          } label: {
            CoachWeekOverviewRow(row: row)
          }
          .buttonStyle(PressScaleButtonStyle(scale: 0.97))
        }
      } else {
        Text(CoachTodayStrings.noTrainingDaysThisWeek)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, MeetPRSpacing.space2)
      }

      Button(action: onViewAll) {
        HStack(spacing: MeetPRSpacing.space1) {
          Text(CoachTodayStrings.viewAllStudents)
            .font(.MeetPR.body(size: 12.5))
            .foregroundStyle(Color.MeetPR.textTertiary)

          Image(systemName: "chevron.right")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size13, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textDisabled)
        }
        .padding(.top, MeetPRSpacing.point2)
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
      }
      .buttonStyle(PressScaleButtonStyle(scale: 0.97))
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.top, MeetPRSpacing.point15)
    .padding(.bottom, MeetPRSpacing.point13)
    .meetPRCardSurface(.card)
  }

  private var summaryHeader: some View {
    HStack(alignment: .bottom) {
      HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.point7) {
        Text("\(summary.completionPercentage)%")
          .font(.MeetPR.display(size: MeetPRFontMetrics.size26))
          .foregroundStyle(Color.MeetPR.textPrimary)

        Text(
          CoachTodayStrings.trainingDaysCompleted(
            completed: summary.completed,
            planned: summary.planned
          )
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textTertiary)
      }

      Spacer(minLength: MeetPRSpacing.space2)

      Text("W\(summary.isoWeek)")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
        .tracking(MeetPRSpacing.point1)
        .foregroundStyle(Color.MeetPR.textDisabled)
    }
  }

  private var legendBars: some View {
    HStack(spacing: MeetPRSpacing.point3) {
      ForEach(summary.legend) { legend in
        Capsule()
          .fill(color(for: legend.group))
          .frame(maxWidth: .infinity)
          .containerRelativeFrame(
            .horizontal,
            count: max(1, summary.rows.count),
            span: legend.count,
            spacing: MeetPRSpacing.point3
          )
      }
    }
    .frame(height: MeetPRSpacing.space2)
  }

  private var legendLabels: some View {
    HStack(spacing: MeetPRSpacing.space3) {
      ForEach(summary.legend) { legend in
        HStack(spacing: MeetPRSpacing.point5) {
          Circle()
            .fill(color(for: legend.group))
            .frame(width: MeetPRSpacing.point7, height: MeetPRSpacing.point7)

          Text(label(for: legend.group))
            .font(.MeetPR.body(size: 11.5))
            .foregroundStyle(Color.MeetPR.textTertiary)

          Text(CoachTodayStrings.peopleCount(legend.count))
            .font(.MeetPR.body(size: 11.5, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var weekdayHeader: some View {
    let weekdays = CoachTodayStrings.weekdays
    return HStack(spacing: MeetPRSpacing.point10) {
      Color.clear
        .frame(width: MeetPRSpacing.point52, height: MeetPRSpacing.point1)

      HStack(spacing: MeetPRSpacing.space1) {
        ForEach(weekdays.indices, id: \.self) { index in
          Text(weekdays[index])
            .font(
              .MeetPR.mono(
                size: 9.5,
                weight: index == summary.todayColumn ? .bold : .regular
              )
            )
            .foregroundStyle(
              index == summary.todayColumn
                ? Color.MeetPR.textPrimary
                : Color.MeetPR.textDisabled
            )
            .frame(maxWidth: .infinity)
        }
      }

      Color.clear
        .frame(width: MeetPRSpacing.point30, height: MeetPRSpacing.point1)
    }
  }

  private func label(for group: CoachWeekOverview.Group) -> String {
    switch group {
    case .active: CoachTodayStrings.activeAsPlanned
    case .idle: CoachTodayStrings.notStarted
    case .attention: CoachTodayStrings.needsAttention
    }
  }

  private func color(for group: CoachWeekOverview.Group) -> Color {
    switch group {
    case .active: Color.MeetPR.success
    case .idle: Color.MeetPR.textDisabled
    case .attention: Color.MeetPR.danger
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct CoachWeekOverviewRow: View {
  let row: CoachWeekOverview.Row

  var body: some View {
    HStack(spacing: MeetPRSpacing.point10) {
      HStack(spacing: MeetPRSpacing.point5) {
        Circle()
          .fill(groupColor)
          .frame(width: MeetPRSpacing.point5, height: MeetPRSpacing.point5)

        Text(row.name)
          .font(.MeetPR.body(size: 12.5, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)
      }
      .frame(width: MeetPRSpacing.point52, alignment: .leading)

      HStack(spacing: MeetPRSpacing.space1) {
        ForEach(row.cells.indices, id: \.self) { index in
          CoachWeekOverviewCell(cell: row.cells[index])
            .frame(maxWidth: .infinity)
        }
      }
      .frame(height: MeetPRSpacing.point14)

      Text("\(row.completed)/\(row.planned)")
        .font(.MeetPR.mono(size: 11.5, weight: .semibold))
        .foregroundStyle(ratioColor)
        .frame(width: MeetPRSpacing.point30, alignment: .trailing)
    }
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }

  private var groupColor: Color {
    switch row.group {
    case .active: Color.MeetPR.success
    case .idle: Color.MeetPR.textDisabled
    case .attention: Color.MeetPR.danger
    }
  }

  private var ratioColor: Color {
    if row.planned > 0, row.completed >= row.planned {
      return Color.MeetPR.success
    }
    if row.group == .attention {
      return Color.MeetPR.danger
    }
    return Color.MeetPR.textTertiary
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct CoachWeekOverviewCell: View {
  let cell: CoachWeekOverview.Cell

  var body: some View {
    switch cell {
    case .rest:
      RoundedRectangle(cornerRadius: MeetPRRadius.micro)
        .fill(Color.MeetPR.bgStack)
        .frame(height: MeetPRSpacing.space1)
        .padding(.top, MeetPRSpacing.point6)
    case .completed:
      RoundedRectangle(cornerRadius: MeetPRRadius.micro)
        .fill(Color.MeetPR.success)
        .frame(height: MeetPRSpacing.point14)
    case .missed(let isAttention):
      RoundedRectangle(cornerRadius: MeetPRRadius.micro)
        .fill(isAttention ? Color.MeetPR.danger.opacity(0.16) : Color.MeetPR.bgBase)
        .frame(height: MeetPRSpacing.point14)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.micro)
            .stroke(
              isAttention ? Color.MeetPR.danger : Color.MeetPR.borderStrong,
              lineWidth: MeetPRSpacing.point1
            )
        }
    case .upcoming:
      RoundedRectangle(cornerRadius: MeetPRRadius.micro)
        .fill(Color.MeetPR.surfaceCard)
        .frame(height: MeetPRSpacing.point14)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.micro)
            .stroke(
              Color.MeetPR.borderStrong,
              style: StrokeStyle(
                lineWidth: MeetPRSpacing.point1,
                dash: [MeetPRSpacing.point2, MeetPRSpacing.point2]
              )
            )
        }
    }
  }
}
// swiftlint:enable file_length
