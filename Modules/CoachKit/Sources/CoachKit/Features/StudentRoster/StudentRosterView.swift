// swiftlint:disable type_body_length
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Coach 学员 tab, reskinned to the design's `RosterList` layout: a custom
/// large-title "学员" header, the 今日分诊 strip, and the roster grouped by
/// lifecycle status (评估期内 / 活跃 / 异常) into bordered card surfaces of
/// dot + name/sub + status badge + chevron rows. This tab shows ONLY accepted
/// students' status; new-student requests live in the 接收 tab. Binds verbatim
/// to `StudentRosterViewModel`; navigation, search, refresh, and the
/// pendingAttentionCount badge semantics are preserved.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentRosterView: View {
  @Bindable private var viewModel: StudentRosterViewModel
  private let context: CoachStudentDetailContext

  init(
    viewModel: StudentRosterViewModel,
    context: CoachStudentDetailContext
  ) {
    self.viewModel = viewModel
    self.context = context
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        header

        content
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bg)
      .hideNavigationBar()
    }
    .task {
      await viewModel.loadIfNeeded()
    }
  }

  // MARK: - Header

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Text("学员")
        .font(.system(size: 36, weight: .heavy))
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Spacer()
      Button {
        Task { await viewModel.refresh() }
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 18))
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .frame(width: 36, height: 36)
          .background(Color.MeetPR.surface1)
          .clipShape(Circle())
          .overlay { Circle().stroke(Color.MeetPR.border, lineWidth: 1) }
      }
      .accessibilityLabel("刷新学员")
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 4)
  }

  // MARK: - Content states

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed(let message):
      ContentUnavailableView(
        "加载失败",
        systemImage: "exclamationmark.triangle",
        description: Text(message)
      )
    case .loaded:
      if viewModel.rows.isEmpty {
        ContentUnavailableView(
          "暂无学员",
          systemImage: "person.2",
          description: Text("在「接收」接收新学员后会出现在这里")
        )
      } else {
        rosterScroll
      }
    }
  }

  // MARK: - Roster scroll

  private var rosterScroll: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        searchField

        if viewModel.pendingAttentionCount > 0 {
          triageSection
        }

        rosterGroups
      }
      .padding(16)
    }
    .scrollContentBackground(.hidden)
    .refreshable {
      await viewModel.refresh()
    }
  }

  /// Inline search bound to `viewModel.searchText`. A custom field (not
  /// `.searchable`) because the nav bar is hidden, so the system search field
  /// would never render — leaving search disconnected from the UI.
  private var searchField: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 15))
        .foregroundStyle(Color.MeetPR.fgTertiary)
      TextField("搜索学员", text: $viewModel.searchText)
        .textFieldStyle(.plain)
        .font(.system(size: 16))
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .submitLabel(.search)
      if !viewModel.searchText.isEmpty {
        Button {
          viewModel.searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 15))
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("清除搜索")
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: 10))
    .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color.MeetPR.border, lineWidth: 1) }
  }

  // MARK: - 今日分诊 strip

  private var triageSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("今天 \(viewModel.pendingAttentionCount) 个需要你")

      groupCard {
        let rows = viewModel.triageRows
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
          NavigationLink {
            StudentDetailView(
              summary: row.student,
              context: context,
              onEvaluationCompleted: { [viewModel] in
                viewModel.markStudentActive(row.student.id)
              },
              onStudentRenamed: { [viewModel] renamed in
                viewModel.applyRenamedStudent(renamed)
              }
            )
          } label: {
            rosterRow(row, showsTopBorder: index > 0)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  // MARK: - Status-grouped roster

  @ViewBuilder
  private var rosterGroups: some View {
    let groups = statusGroups
    if groups.isEmpty {
      sectionLabel("学员")
      Text(
        viewModel.searchText.isEmpty
          ? "暂无学员,在「接收」接收新学员后会出现在这里"
          : "未找到匹配「\(viewModel.searchText)」的学员"
      )
      .font(Font.MeetPR.footnote)
      .foregroundStyle(Color.MeetPR.fgTertiary)
    } else {
      ForEach(groups) { group in
        VStack(alignment: .leading, spacing: 8) {
          sectionLabel("\(group.title) · \(group.rows.count)")
          groupCard {
            ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
              NavigationLink {
                StudentDetailView(
                  summary: row.student,
                  context: context,
                  // Both completion paths (banner [完成评估] and the summary
                  // editor chain) report back here, so the roster row drops its
                  // 评估中 status without waiting for the next full refresh.
                  onEvaluationCompleted: { [viewModel] in
                    viewModel.markStudentActive(row.student.id)
                  },
                  onStudentRenamed: { [viewModel] renamed in
                    viewModel.applyRenamedStudent(renamed)
                  }
                )
              } label: {
                rosterRow(row, showsTopBorder: index > 0)
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
    }
  }

  /// `filteredRows` partitioned into the design's three lifecycle groups,
  /// preserving the model's existing ordering within each. Empty groups are
  /// dropped so the section header count is never `· 0`.
  private var statusGroups: [RosterStatusGroup] {
    let rows = viewModel.filteredRows
    var evaluating: [StudentRosterRowModel] = []
    var active: [StudentRosterRowModel] = []
    var abnormal: [StudentRosterRowModel] = []
    for row in rows {
      switch row.student.status {
      case .inEvaluation: evaluating.append(row)
      case .active: active.append(row)
      case .abnormal: abnormal.append(row)
      }
    }
    return [
      RosterStatusGroup(id: "evaluating", title: "评估期内", rows: evaluating),
      RosterStatusGroup(id: "active", title: "活跃", rows: active),
      RosterStatusGroup(id: "abnormal", title: "异常", rows: abnormal),
    ].filter { !$0.rows.isEmpty }
  }

  // MARK: - Row (dot · name/sub · badge · chevron)

  private func rosterRow(_ row: StudentRosterRowModel, showsTopBorder: Bool) -> some View {
    HStack(spacing: 12) {
      Circle()
        .fill(dotColor(for: row))
        .frame(width: 9, height: 9)

      VStack(alignment: .leading, spacing: 3) {
        Text(row.student.displayName)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(1)
        Text(subtitle(for: row))
          .font(.system(size: 13))
          .foregroundStyle(Color.MeetPR.fgTertiary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      let badge = badge(for: row)
      StatusBadge(status: badge.status, title: badge.title)

      Image(systemName: "chevron.right")
        .font(.system(size: 15))
        .foregroundStyle(Color.MeetPR.fgTertiary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(minHeight: 64)
    .contentShape(Rectangle())
    .overlay(alignment: .top) {
      if showsTopBorder {
        Rectangle().fill(Color.MeetPR.border).frame(height: 1)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(row.student.displayName)
  }

  /// Status dot color mirrors `StudentRosterRow`'s badge intent: needs-attention
  /// rows go red/amber by signal, evaluation amber, active green when this week
  /// is met else fgPrimary, abnormal amber.
  private func dotColor(for row: StudentRosterRowModel) -> Color {
    if row.needsAttention {
      let notTrained = row.triageSignals.contains { signal in
        if case .notTrained = signal { return true }
        return false
      }
      return notTrained ? Color.MeetPR.brandRed : Color.MeetPR.amber
    }
    switch row.student.status {
    case .inEvaluation:
      return Color.MeetPR.amber
    case .active:
      if row.plannedTrainingDays > 0 && row.completedTrainingDays >= row.plannedTrainingDays {
        return Color.MeetPR.green
      }
      return Color.MeetPR.fgPrimary
    case .abnormal:
      return Color.MeetPR.amber
    }
  }

  /// Real second line: completion + last-active for active rows; the status text
  /// (评估期 N 天 / N 天未训练 / W停滞) for evaluation/abnormal rows. The design's
  /// "W3D1 · 训练中 · 第3/4组 / 3视频待看 / 09:00" live-session strings have no
  /// backing field in the row model — degraded to the data we actually have.
  private func subtitle(for row: StudentRosterRowModel) -> String {
    if row.needsAttention {
      let text = StudentTriageSignalCalculator.summaryText(for: row.triageSignals)
      if !text.isEmpty { return text }
    }
    switch row.student.status {
    case .active:
      return row.completionText + " · " + lastActiveText(row)
    case .inEvaluation, .abnormal:
      return row.statusText
    }
  }

  private func lastActiveText(_ row: StudentRosterRowModel) -> String {
    guard let lastActiveAt = row.lastActiveAt else {
      return "暂无训练记录"
    }
    return "上次活跃 \(CoachStudentFormatting.relativeText(lastActiveAt))"
  }

  /// Reuses the real `StudentRosterRow` badge mapping verbatim so the reskin and
  /// the existing row agree on status copy/color.
  private func badge(for row: StudentRosterRowModel) -> (status: StatusBadge.Status, title: String)
  {
    if row.needsAttention {
      return (.live, "待关注")
    }
    switch row.student.status {
    case .active:
      if row.plannedTrainingDays == 0 {
        return (.pending, "暂无计划")
      }
      if row.completedTrainingDays >= row.plannedTrainingDays {
        return (.ready, "本周 \(row.completedTrainingDays)/\(row.plannedTrainingDays)")
      }
      return (.pending, "本周 \(row.completedTrainingDays)/\(row.plannedTrainingDays)")
    case .inEvaluation:
      return (.pending, row.statusText)
    case .abnormal:
      return (.overdue, row.statusText)
    }
  }

  // MARK: - Building blocks

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(Font.MeetPR.monoLabel)
      .tracking(Font.MeetPR.monoLabelTracking)
      .foregroundStyle(Color.MeetPR.fgSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func groupCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(spacing: 0) { content() }
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: 12))
      .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
  }
}

/// One lifecycle group (评估期内 / 活跃 / 异常) of roster rows.
@available(iOS 17.0, macOS 14.0, *)
private struct RosterStatusGroup: Identifiable {
  let id: String
  let title: String
  let rows: [StudentRosterRowModel]
}
// swiftlint:enable type_body_length
