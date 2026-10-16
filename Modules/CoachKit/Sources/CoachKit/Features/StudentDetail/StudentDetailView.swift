// swiftlint:disable type_body_length
import DesignSystem
import RepositoryContracts
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentDetailView: View {
  @Bindable private var viewModel: StudentDetailViewModel
  @State private var videoGridViewModel: StudentVideoGridViewModel
  @State private var growthViewModel: StudentGrowthViewModel
  private let context: CoachStudentDetailContext
  private let onStudentRenamed: (@MainActor (CoachStudentSummary) -> Void)?
  @State private var showComposer = false
  @State private var showRenamePrompt = false
  @State private var renameText = ""
  @State private var renameFailureMessage: String?

  init(
    summary: CoachStudentSummary,
    context: CoachStudentDetailContext,
    onStudentRenamed: (@MainActor (CoachStudentSummary) -> Void)? = nil
  ) {
    viewModel = StudentDetailViewModel(
      summary: summary,
      plans: context.plans,
      trainingLogs: context.trainingLogs,
      feedback: context.feedback,
      videos: context.videos,
      readiness: context.readiness
    )
    _videoGridViewModel = State(
      initialValue: StudentVideoGridViewModel(repository: context.videos)
    )
    _growthViewModel = State(
      initialValue: StudentGrowthViewModel(
        plans: context.plans,
        trainingLogs: context.trainingLogs,
        profiles: context.profiles,
        familyMapProvider: context.familyMapProvider
      )
    )
    self.context = context
    self.onStudentRenamed = onStudentRenamed
  }

  var body: some View {
    VStack(spacing: 0) {
      header

      sectionTabs

      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Spec 029 §risk 5: auto fetch once on appear + pull-to-refresh as
        // the explicit retry path (the "下拉刷新重试" copy in the video wall
        // and readiness row points here). Growth keeps its own cache, so the
        // pull refreshes whichever data the visible section reads.
        .refreshable { [viewModel, growthViewModel] in
          if viewModel.selectedSection == .growth {
            await growthViewModel.load(studentID: viewModel.summary.id)
          } else {
            await viewModel.refresh()
          }
        }
    }
    .background(Color.MeetPR.bg)
    .hideNavigationBar()
    .sheet(isPresented: $showComposer) {
      FeedbackComposerView(
        studentID: viewModel.summary.id,
        studentName: viewModel.summary.displayName,
        days: viewModel.plannedDays,
        repository: context.feedback
      ) { item in
        viewModel.appendPostedFeedback(item)
      }
    }
    .alert("修改学员姓名", isPresented: $showRenamePrompt) {
      TextField("学员姓名", text: $renameText)
      Button("取消", role: .cancel) {}
      Button("保存") {
        Task { await renameStudent() }
      }
      .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    } message: {
      Text("修改后会同步到网页端和学员列表")
    }
    .alert(
      "修改失败",
      isPresented: Binding(
        get: { renameFailureMessage != nil },
        set: { if !$0 { renameFailureMessage = nil } }
      )
    ) {
      Button("确定", role: .cancel) {}
    } message: {
      Text(renameFailureMessage ?? "请稍后重试")
    }
    .task {
      await viewModel.loadIfNeeded()
    }
  }

  // MARK: - Header (custom large title + student identity + status)

  /// Reskins the mock's nav bar (back chevron · name · ellipsis) into the house
  /// large-title header: a back affordance row, the student's real
  /// `displayName`, a status line, and — when the active feedback section
  /// exposes it — the 写反馈 compose action that previously lived in the
  /// nav-bar toolbar (preserved verbatim, just relocated into the header).
  private var header: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      backRow

      HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.md) {
        Text(viewModel.summary.displayName)
          .font(.system(size: 34, weight: .heavy))
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Spacer(minLength: MeetPRSpacing.sm)
        let badge = statusBadge
        StatusBadge(status: badge.status, title: badge.title)
      }

      Text(statusLine)
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.fgSecondary)
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.top, MeetPRSpacing.sm)
    .padding(.bottom, MeetPRSpacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @Environment(\.dismiss) private var dismiss

  private var backRow: some View {
    HStack {
      Button {
        dismiss()
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "chevron.left")
          Text("学员")
        }
        .font(Font.MeetPR.body)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("返回学员列表")

      Spacer()

      Button {
        renameText = viewModel.summary.displayName
        showRenamePrompt = true
      } label: {
        Image(systemName: "pencil")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .frame(width: 36, height: 36)
          .background(Color.MeetPR.surface1)
          .clipShape(Circle())
          .overlay { Circle().stroke(Color.MeetPR.border, lineWidth: 1) }
      }
      .buttonStyle(.plain)
      .accessibilityLabel("修改学员姓名")

      if viewModel.selectedSection == .feedback {
        Button {
          showComposer = true
        } label: {
          Image(systemName: "square.and.pencil")
            .font(.system(size: 18))
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .frame(width: 36, height: 36)
            .background(Color.MeetPR.surface1)
            .clipShape(Circle())
            .overlay { Circle().stroke(Color.MeetPR.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("写反馈")
      }
    }
  }

  private func renameStudent() async {
    let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, name.count <= 100, name != viewModel.summary.displayName else { return }
    do {
      let renamed = try await context.planning.renameStudent(
        id: viewModel.summary.id,
        displayName: name
      )
      viewModel.applyRenamedStudent(renamed)
      onStudentRenamed?(renamed)
    } catch {
      renameFailureMessage = "无法修改学员姓名，请检查网络后重试"
    }
  }

  /// Status line beneath the name using the real active/abnormal state.
  private var statusLine: String {
    switch viewModel.summary.status {
    case .active:
      return "学员 · 活跃"
    case .abnormal:
      return "学员 · 异常"
    }
  }

  /// Maps the visible lifecycle status to a `StatusBadge`.
  private var statusBadge: (status: StatusBadge.Status, title: String) {
    switch viewModel.summary.status {
    case .active:
      return (.ready, "活跃")
    case .abnormal:
      return (.overdue, "异常")
    }
  }

  // MARK: - Section tabs (reskinned segmented picker)

  /// The five-section switch is core behavior (drives `selectedSection`, which
  /// every sub-view and the toolbar depend on), so the segmented `Picker` is
  /// preserved verbatim — only its surround is restyled to the house card:
  /// a mono section label over a bordered surface that contains the picker.
  private var sectionTabs: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Eyebrow("学员档案")

      Picker("", selection: $viewModel.selectedSection) {
        ForEach(StudentDetailSection.allCases) { section in
          Text(section.title).tag(section)
        }
      }
      .pickerStyle(.segmented)
    }
    .padding(MeetPRSpacing.base)
  }

  // MARK: - Content states (reskinned loading / failure)

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .idle, .loading:
      VStack(spacing: MeetPRSpacing.md) {
        Spacer()
        ProgressView()
          .tint(Color.MeetPR.brandRed)
        Text("加载学员详情…")
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.fgTertiary)
        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed(let message):
      detailFailureCard(message)
    case .loaded:
      sectionContent
    }
  }

  /// House-style failure surface in place of the bare `ContentUnavailableView`,
  /// preserving the failed-state message verbatim.
  private func detailFailureCard(_ message: String) -> some View {
    VStack {
      Spacer()
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow("加载失败", color: Color.MeetPR.brandRed)
        Text(message)
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text("下拉刷新重试")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
      .padding(MeetPRSpacing.base)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(Color.MeetPR.border, lineWidth: 1)
      }
      .padding(.horizontal, MeetPRSpacing.base)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var sectionContent: some View {
    switch viewModel.selectedSection {
    case .overview:
      StudentOverviewSection(
        summary: viewModel.overview,
        readiness: viewModel.todayReadiness,
        recentVideos: viewModel.recentVideos,
        videosUnavailable: viewModel.videosUnavailable,
        onSelectSection: { section in
          viewModel.select(section)
        }
      )
    case .execution:
      StudentExecutionView(days: viewModel.executionDays)
    case .videos:
      StudentVideoGridView(
        videos: viewModel.videos,
        unavailable: viewModel.videosUnavailable,
        viewModel: videoGridViewModel
      )
    case .growth:
      StudentGrowthView(studentID: viewModel.summary.id, viewModel: growthViewModel)
    case .feedback:
      CoachFeedbackHistoryView(
        feedback: viewModel.feedbackItems,
        days: viewModel.plannedDays,
        onCompose: {
          showComposer = true
        }
      )
    }
  }
}

// swiftlint:enable type_body_length
