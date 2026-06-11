import DesignSystem
import SwiftUI

/// The 3-field evaluation summary editor (spec 033 §8) plus the soft
/// recommendation → planning prefill handoff (§9).
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct EvaluationSummaryEditorView: View {
  @State private var viewModel: EvaluationSummaryEditorViewModel
  private let context: CoachStudentDetailContext
  @State private var planningIntent: PlanningIntentBox?

  init(viewModel: EvaluationSummaryEditorViewModel, context: CoachStudentDetailContext) {
    _viewModel = State(initialValue: viewModel)
    self.context = context
  }

  var body: some View {
    Group {
      switch viewModel.state {
      case .loading:
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      case .failed:
        ContentUnavailableView(
          "加载失败",
          systemImage: "exclamationmark.triangle",
          description: Text("评估总结加载失败,请返回重试")
        )
      case .ready:
        editorForm
      }
    }
    .background(Color.MeetPR.bg)
    .navigationTitle("评估总结 · \(viewModel.student.displayName)")
    .task {
      if viewModel.state == .loading {
        await viewModel.load()
      }
    }
    .alert(
      "评估完成,\(viewModel.student.displayName) 已收到通知。",
      isPresented: Bindable(viewModel).showSoftRecommendation
    ) {
      Button("稍后", role: .cancel) {}
      Button("立即排") {
        Task {
          let profile = await viewModel.fetchPrefillProfile()
          planningIntent = PlanningIntentBox(
            intent: .firstRegularPlan(viewModel.student, profile))
        }
      }
    } message: {
      Text("要不要立即为他排第一份正式计划?")
    }
    #if os(iOS)
      .fullScreenCover(item: $planningIntent) { box in
        PlanningCoordinatorView(
          repository: context.planning,
          draftStore: context.draftStore,
          intent: box.intent
        )
      }
    #else
      .sheet(item: $planningIntent) { box in
        PlanningCoordinatorView(
          repository: context.planning,
          draftStore: context.draftStore,
          intent: box.intent
        )
      }
    #endif
  }

  private var editorForm: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        if let notice = viewModel.noticeMessage {
          noticeCard(notice, color: Color.MeetPR.amber)
        }
        if let prefillNotice = viewModel.prefillNotice {
          noticeCard(prefillNotice, color: Color.MeetPR.fgSecondary)
        }

        fieldCard(
          title: "整体评估(必填)",
          text: Bindable(viewModel).overallAssessment
        )
        fieldCard(
          title: "训练规划(必填)",
          text: Bindable(viewModel).trainingPlanText
        )
        fieldCard(
          title: "给学员的话(选填)",
          text: Bindable(viewModel).wordsToStudent
        )

        actionArea
      }
      .padding(MeetPRSpacing.base)
    }
  }

  @ViewBuilder
  private var actionArea: some View {
    if viewModel.isEditMode {
      Toggle("同时通知学员", isOn: Bindable(viewModel).notifyOnSave)
        .font(Font.MeetPR.body)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      PrimaryButton(
        "保存",
        isDisabled: !viewModel.canSave || viewModel.isSaving,
        isFullWidth: true
      ) {
        Task { _ = await viewModel.save() }
      }
    } else {
      HStack(spacing: MeetPRSpacing.sm) {
        SecondaryButton(
          "保存草稿",
          isDisabled: !viewModel.canSave || viewModel.isSaving,
          isFullWidth: true
        ) {
          Task { _ = await viewModel.save() }
        }
        PrimaryButton(
          "完成并通知学员",
          isDisabled: !viewModel.canSave || viewModel.isSaving,
          isFullWidth: true
        ) {
          Task { _ = await viewModel.completeAndNotify() }
        }
      }
    }

    if let savedAt = viewModel.lastSavedAt {
      Text("已保存 \(CoachStudentFormatting.relativeText(savedAt))")
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.fgTertiary)
    }
  }

  private func fieldCard(title: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Eyebrow(title)
      TextEditor(text: text)
        .frame(minHeight: 96)
        .scrollContentBackground(.hidden)
        .padding(MeetPRSpacing.sm)
        .background(Color.MeetPR.surface1)
        .clipShape(.rect(cornerRadius: MeetPRRadius.md))
        .font(Font.MeetPR.body)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .onChange(of: text.wrappedValue) { _, newValue in
          if newValue.count > EvaluationSummaryEditorViewModel.maxFieldLength {
            text.wrappedValue = String(
              newValue.prefix(EvaluationSummaryEditorViewModel.maxFieldLength))
          }
        }
    }
  }

  private func noticeCard(_ message: String, color: Color) -> some View {
    Label(message, systemImage: "info.circle")
      .font(Font.MeetPR.footnote)
      .foregroundStyle(color)
  }
}

/// Identifiable box so fullScreenCover(item:) can present a PlanningIntent.
private struct PlanningIntentBox: Identifiable {
  let id = UUID()
  let intent: PlanningIntent
}
