import DesignSystem
import Foundation
import SwiftUI

/// Coach 今日 tab — reskinned 1:1 to `DKCoachDashboard` (今日仪表盘): a custom
/// large-title header, a red new-student-request card, a 2-stat overview, and a
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

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        header
        ScrollView {
          VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
            if pendingCount > 0 { newStudentCard }
            statsCard
            todaySection
          }
          .padding(MeetPRSpacing.base)
        }
        .scrollContentBackground(.hidden)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bg)
      .hideNavigationBar()
    }
  }

  // MARK: - Header

  /// Custom large-title lockup (matches the student-side reskins): mono date
  /// eyebrow + heavy display title. The mock's "第 03 周" week index has no
  /// backing field on the dashboard, so the eyebrow shows today's real date.
  private var header: some View {
    HStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        Eyebrow(Self.headerEyebrow)
        Text("今日")
          .font(.system(size: 36, weight: .heavy))
          .foregroundStyle(Color.MeetPR.fgPrimary)
      }
      Spacer()
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.top, MeetPRSpacing.xs)
    .padding(.bottom, MeetPRSpacing.md)
  }

  // MARK: - New-student request card

  private var newStudentCard: some View {
    Button(action: onOpenReceiving) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: MeetPRSpacing.sm) {
          Circle().fill(Color.MeetPR.brandRed).frame(width: 6, height: 6)
          Text("新学员请求 // \(String(format: "%02d", pendingCount))")
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.brandRed)
        }
        Text("\(pendingCount) 名新学员等待你接收")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .padding(.top, MeetPRSpacing.sm)
        Text("查看接收队列 →")
          .font(.system(size: 14))
          .foregroundStyle(Color.MeetPR.fgSecondary)
          .padding(.top, MeetPRSpacing.xs + 2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.base)
      .background(Color.MeetPR.surface2)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(Color.MeetPR.brandRed.opacity(0.3), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }

  // MARK: - 2-stat overview

  /// Two at-a-glance counts derived from real roster and triage data.
  private var statsCard: some View {
    HStack(spacing: 0) {
      statColumn(
        label: "学员", value: activeCount, unit: "活跃",
        valueColor: Color.MeetPR.fgPrimary)
      divider
      Button(action: onOpenRoster) {
        statContent(
          label: "待关注", value: attentionCount, unit: "学员",
          valueColor: attentionCount > 0 ? Color.MeetPR.brandRed : Color.MeetPR.fgPrimary)
      }
      .buttonStyle(.plain)
    }
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg).stroke(Color.MeetPR.border, lineWidth: 1)
    }
  }

  private var divider: some View {
    Rectangle()
      .fill(Color.MeetPR.border)
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
        .foregroundStyle(Color.MeetPR.brandRed)
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.xs) {
        Text("\(value)")
          .font(.system(size: 36, weight: .heavy).monospacedDigit())
          .foregroundStyle(valueColor)
        Text(unit)
          .font(.system(size: 13))
          .foregroundStyle(Color.MeetPR.fgTertiary)
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
        .foregroundStyle(Color.MeetPR.fgSecondary)
      todayCard
    }
  }

  @ViewBuilder
  private var todayCard: some View {
    if todayRows.isEmpty {
      emptyTodayCard
    } else {
      VStack(spacing: 0) {
        ForEach(Array(todayRows.enumerated()), id: \.element.id) { index, row in
          NavigationLink {
            StudentDetailView(summary: row.student, context: context)
          } label: {
            athleteRow(row, showsTopBorder: index > 0)
          }
          .buttonStyle(.plain)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg).stroke(Color.MeetPR.border, lineWidth: 1)
      }
    }
  }

  private var emptyTodayCard: some View {
    HStack(spacing: MeetPRSpacing.md) {
      Image(systemName: "checkmark.circle")
        .font(.system(size: 20))
        .foregroundStyle(Color.MeetPR.green)
      Text(rows.isEmpty ? "暂无学员" : "今天没有需要你处理的学员")
        .font(.system(size: 14))
        .foregroundStyle(Color.MeetPR.fgSecondary)
      Spacer()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg).stroke(Color.MeetPR.border, lineWidth: 1)
    }
  }

  private func athleteRow(_ row: StudentRosterRowModel, showsTopBorder: Bool) -> some View {
    HStack(spacing: MeetPRSpacing.md) {
      Circle().fill(dotColor(for: row)).frame(width: 9, height: 9)
      VStack(alignment: .leading, spacing: 3) {
        Text(row.student.displayName)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text(subtitle(for: row))
          .font(.system(size: 13))
          .foregroundStyle(Color.MeetPR.fgTertiary)
          .lineLimit(1)
      }
      Spacer()
      if let badge = badge(for: row) {
        StatusBadge(status: badge.status, title: badge.title)
      }
      Image(systemName: "chevron.right")
        .font(.system(size: 15))
        .foregroundStyle(Color.MeetPR.fgTertiary)
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.vertical, MeetPRSpacing.base - 2)
    .frame(minHeight: 64)
    .overlay(alignment: .top) {
      if showsTopBorder { Rectangle().fill(Color.MeetPR.border).frame(height: 1) }
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

  /// Red for a missed-training signal (most urgent), amber for awaiting-reply /
  /// feedback, green for an active student in good standing — mirrors the
  /// mock's per-row dot color semantics using REAL triage state.
  private func dotColor(for row: StudentRosterRowModel) -> Color {
    if row.triageSignals.contains(where: {
      if case .notTrained = $0 { return true }
      return false
    }) {
      return Color.MeetPR.brandRed
    }
    if !row.triageSignals.isEmpty { return Color.MeetPR.amber }
    return Color.MeetPR.green
  }

  /// Real subtitle: completion progress + a triage hint when present.
  private func subtitle(for row: StudentRosterRowModel) -> String {
    let triage = StudentTriageSignalCalculator.summaryText(for: row.triageSignals)
    if !triage.isEmpty {
      return "\(row.completionText) · \(triage)"
    }
    return row.completionText
  }

  /// Maps real triage / status to the design's badge vocabulary. The mock's
  /// 训练中 (live) / 就绪 (ready) / e1RM PR badges have no backing signal on the
  /// roster model, so they are not fabricated — only real triage signals map
  /// to badges.
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
            status: .active
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
    /// push.
    static var context: CoachStudentDetailContext {
      CoachStudentDetailContext(
        plans: EmptyStudentPlanRepository(),
        trainingLogs: EmptyStudentTrainingLogRepository(),
        feedback: EmptyStudentFeedbackRepository(),
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
      rows: CoachDashboardPreview.rows
    )
    .preferredColorScheme(.dark)
  }
#endif
