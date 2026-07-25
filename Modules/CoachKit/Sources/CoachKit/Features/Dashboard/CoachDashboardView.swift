// swiftlint:disable file_length type_body_length
import DesignSystem
import Foundation
import SwiftUI

/// Coach 今日 tab — reskinned 1:1 to `DKCoachDashboard` (今日仪表盘): a custom
/// large-title header, a red new-student-request card, a 3-stat overview, and a
/// "今日 — 学员" triage list. Every figure is bound to the REAL coach view models
/// (`StudentRosterViewModel` triage rows + `BindQueueViewModel.pendingCount`);
/// where the mock invents data the model does not carry (per-row 训练中 / 就绪 /
/// e1RM PR badges, scheduled 09:00, "已等待 18 小时", 待反馈视频数), the view
/// degrades honestly to the real triage signal / student status instead of
/// fabricating it.
///
/// `CoachRootView` passes `rosterViewModel.rows` so the triage list paints with
/// live data, plus the shared `CoachStudentDetailContext` so tapping a today-row
/// pushes `StudentDetailView` in this tab's own `NavigationStack` — the same
/// destination the 学员 tab's 今日分诊 strip uses (see crossFileWiring).
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachDashboardView: View {
  let attentionCount: Int
  let pendingCount: Int
  /// Shared detail dependencies (the same bundle the 学员 tab threads) so a
  /// today-row tap opens `StudentDetailView` without a second network fetch.
  let context: CoachStudentDetailContext
  /// Live roster snapshot from `StudentRosterViewModel.rows`. Empty by default;
  /// the today-list and the overview counts derive from it when supplied.
  var rows: [StudentRosterRowModel] = []
  var onOpenReceiving: @MainActor () -> Void = {}
  var onOpenRoster: @MainActor () -> Void = {}
  /// Forwards an evaluation completion to `StudentRosterViewModel` so the row
  /// sheds its 评估中 status without waiting for the next refresh — mirrors the
  /// 学员 tab's triage rows.
  var onEvaluationCompleted: @MainActor (UUID) -> Void = { _ in }
  var chat: CoachChatContext?
  @State private var isConversationListPresented = false

  var body: some View {
    NavigationStack {
      VStack(spacing: MeetPRSpacing.zero) {
        header
        ScrollView {
          VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
            if pendingCount > 0 {
              newStudentCard
                .meetPRRiseIn(index: 1)
            }
            statsCard
              .meetPRRiseIn(index: 2)
            todaySection
              .meetPRRiseIn(index: 3)
          }
          .padding(.horizontal, MeetPRSpacing.pageHorizontal)
          .padding(.vertical, MeetPRSpacing.point14)
        }
        .scrollContentBackground(.hidden)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bgBase)
      .hideNavigationBar()
      .navigationDestination(isPresented: $isConversationListPresented) {
        if let chat {
          ConversationListView(chat: chat)
        }
      }
    }
  }

  // MARK: - Header

  /// Custom large-title lockup (matches the student-side reskins): mono date
  /// eyebrow + heavy display title. The mock's "第 03 周" week index has no
  /// backing field on the dashboard, so the eyebrow shows today's real date.
  private var header: some View {
    HStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        Text(Self.headerEyebrow)
          .font(.MeetPR.mono(size: 12, weight: .medium))
          .tracking(0.72)
          .foregroundStyle(Color.MeetPR.textMuted)
        Text("今日")
          .font(.MeetPR.display(size: 38, weight: .extraBold))
          .tracking(-0.8)
          .foregroundStyle(Color.MeetPR.textPrimary)
      }
      Spacer()
      CoachChatHeaderButton(chat: chat) {
        isConversationListPresented = true
      }
    }
    .padding(.horizontal, MeetPRSpacing.pageHorizontal)
    .padding(.top, MeetPRSpacing.xs)
    .padding(.bottom, MeetPRSpacing.md)
    .meetPRRiseIn(index: 0)
  }

  // MARK: - New-student request card

  private var newStudentCard: some View {
    Button(action: onOpenReceiving) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
        HStack(spacing: MeetPRSpacing.sm) {
          Circle().fill(Color.MeetPR.danger).frame(width: 7, height: 7)
          Text("新学员请求 // \(String(format: "%02d", pendingCount))")
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.textMuted)
        }
        Text("\(pendingCount) 名新学员等待你接收")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size17, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .padding(.top, MeetPRSpacing.sm)
        Text("查看接收队列 →")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size14))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .padding(.top, MeetPRSpacing.xs + 2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.base)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
      }
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  // MARK: - 3-stat overview

  /// Three at-a-glance counts. All derive from real data: 活跃 / 评估期 from the
  /// roster snapshot status, 待关注 from the triage count. The mock's third
  /// column was "待反馈 · 视频 12" — the dashboard has no video-review field, so
  /// it is substituted with the real 待关注 (triage) count, which IS actionable
  /// from this screen.
  private var statsCard: some View {
    HStack(spacing: MeetPRSpacing.zero) {
      statColumn(label: "学员", value: activeCount, unit: "活跃", valueColor: Color.MeetPR.textPrimary)
      divider
      statColumn(
        label: "评估期", value: inEvaluationCount, unit: "进行中",
        valueColor: inEvaluationCount > 0 ? Color.MeetPR.gold500 : Color.MeetPR.textPrimary)
      divider
      Button(action: onOpenRoster) {
        statContent(
          label: "待关注", value: attentionCount, unit: "学员",
          valueColor: attentionCount > 0 ? Color.MeetPR.danger : Color.MeetPR.textPrimary)
      }
      .buttonStyle(PressScaleButtonStyle())
    }
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg).stroke(
        Color.MeetPR.borderDefault, lineWidth: 1)
    }
  }

  private var divider: some View {
    Rectangle()
      .fill(Color.MeetPR.borderDefault)
      .frame(width: 1, height: 48)
      .padding(.horizontal, MeetPRSpacing.md)
  }

  private func statColumn(label: String, value: Int, unit: String, valueColor: Color) -> some View {
    statContent(label: label, value: value, unit: unit, valueColor: valueColor)
  }

  private func statContent(label: String, value: Int, unit: String, valueColor: Color)
    -> some View
  {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      Text(label)
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.gold500)
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.xs) {
        Text("\(value)")
          .font(.MeetPR.display(size: 30, weight: .extraBold).monospacedDigit())
          .foregroundStyle(valueColor)
        Text(unit)
          .font(.MeetPR.system(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textTertiary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - 今日 — 学员 (triage list)

  /// Mock label is "学员 — 今日"; the rows below are the live triage list. Tapping
  /// a row pushes `StudentDetailView` inside this tab's `NavigationStack` — the
  /// same destination as the 学员 tab's 今日分诊 strip, so the coach reaches a
  /// student's detail in one tap instead of bouncing through the roster.
  private var todaySection: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Text("学员 — 今日")
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.textSecondary)
      todayCard
    }
  }

  @ViewBuilder
  private var todayCard: some View {
    if todayRows.isEmpty {
      emptyTodayCard
    } else {
      VStack(spacing: MeetPRSpacing.zero) {
        ForEach(Array(todayRows.enumerated()), id: \.element.id) { index, row in
          NavigationLink {
            StudentDetailView(
              summary: row.student,
              context: context,
              onEvaluationCompleted: { onEvaluationCompleted(row.student.id) }
            )
          } label: {
            athleteRow(row, showsTopBorder: index > 0)
          }
          .buttonStyle(PressScaleButtonStyle())
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg).stroke(
          Color.MeetPR.borderDefault, lineWidth: 1)
      }
    }
  }

  private var emptyTodayCard: some View {
    HStack(spacing: MeetPRSpacing.md) {
      Image(systemName: "checkmark.circle")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size20))
        .foregroundStyle(Color.MeetPR.success)
      Text(rows.isEmpty ? "暂无学员" : "今天没有需要你处理的学员")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size14))
        .foregroundStyle(Color.MeetPR.textSecondary)
      Spacer()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg).stroke(
        Color.MeetPR.borderDefault, lineWidth: 1)
    }
  }

  private func athleteRow(_ row: StudentRosterRowModel, showsTopBorder: Bool) -> some View {
    HStack(spacing: MeetPRSpacing.md) {
      Circle().fill(dotColor(for: row)).frame(width: 9, height: 9)
      VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
        Text(row.student.displayName)
          .font(.MeetPR.body(size: 16, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(subtitle(for: row))
          .font(.MeetPR.system(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .lineLimit(1)
      }
      Spacer()
      if let badge = badge(for: row) {
        StatusBadge(status: badge.status, title: badge.title)
      }
      Image(systemName: "chevron.right")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size15))
        .foregroundStyle(Color.MeetPR.textTertiary)
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.vertical, MeetPRSpacing.base - 2)
    .frame(minHeight: 64)
    .overlay(alignment: .top) {
      if showsTopBorder { Rectangle().fill(Color.MeetPR.borderDefault).frame(height: 1) }
    }
  }

  // MARK: - Derived data

  /// Triage-first ordering (the mock's list leads with the students that need
  /// the coach today): rows with signals on top, then the rest.
  private var todayRows: [StudentRosterRowModel] {
    let triage = rows.filter(\.needsAttention)
    let rest = rows.filter { !$0.needsAttention }
    return triage + rest
  }

  private var activeCount: Int {
    rows.filter { $0.student.status == .active }.count
  }

  private var inEvaluationCount: Int {
    rows.filter {
      if case .inEvaluation = $0.student.status { return true }
      return false
    }.count
  }

  /// Red for a missed-training signal (most urgent), amber for awaiting-reply /
  /// evaluation, green for an active student in good standing — mirrors the
  /// mock's per-row dot color semantics using REAL triage state.
  private func dotColor(for row: StudentRosterRowModel) -> Color {
    row.statusTone.color
  }

  /// Real subtitle: completion progress + a triage hint when present, else the
  /// student status text. No fabricated "W3D1 · 第 3/4 组 · 09:00".
  private func subtitle(for row: StudentRosterRowModel) -> String {
    let triage = StudentTriageSignalCalculator.summaryText(for: row.triageSignals)
    if !triage.isEmpty {
      return "\(row.completionText) · \(triage)"
    }
    if case .inEvaluation = row.student.status {
      return row.statusText
    }
    return row.completionText
  }

  /// Maps real triage / status to the design's badge vocabulary. The mock's
  /// 训练中 (live) / 就绪 (ready) / e1RM PR badges have no backing signal on the
  /// roster model, so they are not fabricated — only 逾期 (missed-training) and
  /// 评估中 (in-evaluation) map to real state; everything else shows no badge.
  private func badge(for row: StudentRosterRowModel) -> (status: StatusBadge.Status, title: String)?
  {
    if row.triageSignals.contains(where: {
      if case .notTrained = $0 { return true }
      return false
    }) {
      return (.overdue, "逾期")
    }
    if row.triageSignals.contains(.awaitingReply) {
      return (.overdue, "待回复")
    }
    if case .inEvaluation = row.student.status {
      return (.pending, "评估中")
    }
    return nil
  }

  // MARK: - Formatting

  private static var headerEyebrow: String {
    Self.eyebrowFormatter.string(from: Date())
  }

  private static let eyebrowFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_Hans_CN")
    formatter.setLocalizedDateFormatFromTemplate("MMMd EEEE")
    return formatter
  }()
}

#if DEBUG
  @MainActor
  @available(iOS 17.0, macOS 14.0, *)
  private enum CoachDashboardPreview {
    static func uuid(_ byte: UInt8) -> UUID {
      UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, byte))
    }

    static var rows: [StudentRosterRowModel] {
      [
        StudentRosterRowModel(
          student: CoachStudentSummary(id: uuid(1), displayName: "陈磊", status: .active),
          plannedTrainingDays: 4,
          completedTrainingDays: 1,
          lastActiveAt: Date(),
          triageSignals: [.notTrained(daysMissed: 3)]
        ),
        StudentRosterRowModel(
          student: CoachStudentSummary(id: uuid(2), displayName: "张宇", status: .active),
          plannedTrainingDays: 4,
          completedTrainingDays: 2,
          lastActiveAt: Date(),
          triageSignals: [.awaitingReply]
        ),
        StudentRosterRowModel(
          student: CoachStudentSummary(
            id: uuid(3),
            displayName: "马伟",
            status: .inEvaluation(remainingDays: 4, remainingHours: 0)
          ),
          plannedTrainingDays: 3,
          completedTrainingDays: 3,
          lastActiveAt: Date(),
          triageSignals: []
        ),
        StudentRosterRowModel(
          student: CoachStudentSummary(id: uuid(4), displayName: "刘浩", status: .active),
          plannedTrainingDays: 4,
          completedTrainingDays: 4,
          lastActiveAt: Date(),
          triageSignals: []
        ),
      ]
    }

    /// In-memory detail dependencies so the preview exercises the row → detail
    /// push; mirrors `TriageStripSection`'s preview context.
    static var context: CoachStudentDetailContext {
      CoachStudentDetailContext(
        plans: EmptyStudentPlanRepository(),
        trainingLogs: EmptyStudentTrainingLogRepository(),
        feedback: EmptyStudentFeedbackRepository(),
        evaluations: InMemoryCoachEvaluationRepository(),
        summaries: InMemoryCoachEvaluationSummaryRepository(coachId: uuid(30)),
        profiles: InMemoryCoachStudentProfileReader(),
        videos: InMemoryCoachStudentVideoRepository(),
        readiness: EmptyReadinessRepository(),
        familyMapProvider: nil,
        planning: InMemoryPlanRepository(students: [], catalog: []),
        draftStore: (try? DraftStore.inMemory()) ?? DraftStore.shared
      )
    }
  }

  @available(iOS 17.0, macOS 14.0, *)
  #Preview("Coach 今日") {
    CoachDashboardView(
      attentionCount: 2,
      pendingCount: 2,
      context: CoachDashboardPreview.context,
      rows: CoachDashboardPreview.rows,
      chat: nil
    )
    .preferredColorScheme(.dark)
  }
#endif
// swiftlint:enable file_length type_body_length
