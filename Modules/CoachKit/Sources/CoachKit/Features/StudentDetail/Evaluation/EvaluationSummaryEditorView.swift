import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// The 3-field evaluation summary editor (spec 033 §8) plus the soft
/// recommendation → planning prefill handoff (§9), reskinned 1:1 to the
/// `DKCoachEvalSummary` mock: brandRed mono field labels over bordered
/// surface1 text-entry cards, the notify row + a high-contrast primary
/// "完成并通知学员" action pinned under the fields, and the 保存草稿 / 保存
/// path kept exactly.
///
/// ALL behavior is preserved verbatim: the load/failed/ready state switch,
/// the `.task` load, every field binding + char-limit clamp, the
/// `noticeMessage` / `prefillNotice` surfaces, `canSave` / `isSaving`
/// disabled logic, `lastSavedAt`, the `isEditMode` branch (notify toggle +
/// 保存 vs 保存草稿 + 完成并通知学员), the `save()` / `completeAndNotify()`
/// VM calls, and the soft-recommendation alert → `fetchPrefillProfile()` →
/// `PlanningCoordinatorView` handoff. Only presentation changed.
///
/// HONEST DEGRADE: the mock's amber "评估期还剩 4 天 13 小时" countdown chip
/// has no backing field on the view model (the live `EvaluationPeriod` is
/// `@ObservationIgnored` and exposes no remaining-time read-model), so it is
/// omitted rather than fabricated — the navigation title already carries the
/// evaluation context. See honestDegrades.
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
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase)
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
          intent: box.intent,
          profiles: context.profiles
        )
      }
    #else
      .sheet(item: $planningIntent) { box in
        PlanningCoordinatorView(
          repository: context.planning,
          draftStore: context.draftStore,
          intent: box.intent,
          profiles: context.profiles
        )
      }
    #endif
  }

  // MARK: - Form

  private var editorForm: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        if let notice = viewModel.noticeMessage {
          noticeCard(notice, color: Color.MeetPR.danger, systemImage: "exclamationmark.triangle")
        }
        if let prefillNotice = viewModel.prefillNotice {
          noticeCard(prefillNotice, color: Color.MeetPR.textSecondary, systemImage: "info.circle")
        }

        fieldCard(
          title: "整体评估 · 必填",
          text: Bindable(viewModel).overallAssessment,
          minHeight: 104
        )
        fieldCard(
          title: "训练规划 · 必填",
          text: Bindable(viewModel).trainingPlanText,
          minHeight: 104
        )
        fieldCard(
          title: "给学员的话 · 选填",
          text: Bindable(viewModel).wordsToStudent,
          minHeight: 84
        )

        actionArea
      }
      .padding(MeetPRSpacing.base)
    }
    .scrollContentBackground(.hidden)
  }

  // MARK: - Bottom action area

  @ViewBuilder
  private var actionArea: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      if viewModel.isEditMode {
        notifyToggleRow
        PrimaryButton(
          "保存",
          isDisabled: !viewModel.canSave || viewModel.isSaving,
          isFullWidth: true
        ) {
          Task { _ = await viewModel.save() }
        }
      } else {
        // Mock: a single high-contrast "完成 + 通知学员" primary, with
        // "保存草稿" demoted to a tertiary text action below it.
        PrimaryButton(
          "完成并通知学员",
          isDisabled: !viewModel.canSave || viewModel.isSaving,
          isFullWidth: true
        ) {
          Task { _ = await viewModel.completeAndNotify() }
        }

        Button {
          Task { _ = await viewModel.save() }
        } label: {
          Text("保存草稿")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size14))
            .foregroundStyle(Color.MeetPR.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, MeetPRSpacing.point14)
            .padding(.bottom, MeetPRSpacing.space1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!viewModel.canSave || viewModel.isSaving)
      }
    }
    .padding(.top, MeetPRSpacing.sm)

    if let savedAt = viewModel.lastSavedAt {
      Text("已保存 \(CoachStudentFormatting.relativeText(savedAt))")
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.textTertiary)
        .frame(maxWidth: .infinity, alignment: .center)
    }
  }

  /// Edit-mode "同时通知学员" opt-in (D4), restyled as the mock's checkbox row.
  private var notifyToggleRow: some View {
    Button {
      viewModel.notifyOnSave.toggle()
    } label: {
      HStack(spacing: MeetPRSpacing.point10) {
        Image(systemName: viewModel.notifyOnSave ? "checkmark" : "")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size13, weight: .bold))
          .foregroundStyle(Color.white)
          .frame(width: 22, height: 22)
          .background(viewModel.notifyOnSave ? Color.MeetPR.gold500 : Color.MeetPR.surfaceElevated)
          .clipShape(.rect(cornerRadius: MeetPRRadius.point5))
          .overlay {
            RoundedRectangle(cornerRadius: MeetPRRadius.point5)
              .stroke(Color.MeetPR.borderDefault, lineWidth: viewModel.notifyOnSave ? 0 : 1)
          }
        Text("同时通知学员")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size15))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Spacer()
      }
      .padding(.bottom, MeetPRSpacing.point14)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityLabel("同时通知学员")
    .accessibilityValue(viewModel.notifyOnSave ? "已选中" : "未选中")
  }

  // MARK: - Building blocks

  private func fieldCard(title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Text(title)
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.gold500)

      TextEditor(text: text)
        .frame(minHeight: minHeight)
        .scrollContentBackground(.hidden)
        .padding(MeetPRSpacing.md)
        .background(Color.MeetPR.surfaceCard)
        .clipShape(.rect(cornerRadius: MeetPRRadius.md))
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.md)
            .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
        }
        .font(Font.MeetPR.body)
        .foregroundStyle(Color.MeetPR.textPrimary)
        .onChange(of: text.wrappedValue) { _, newValue in
          if newValue.count > EvaluationSummaryEditorViewModel.maxFieldLength {
            text.wrappedValue = String(
              newValue.prefix(EvaluationSummaryEditorViewModel.maxFieldLength))
          }
        }
    }
  }

  private func noticeCard(_ message: String, color: Color, systemImage: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
      Image(systemName: systemImage)
        .font(.MeetPR.system(size: MeetPRFontMetrics.size14))
        .foregroundStyle(color)
      Text(message)
        .font(Font.MeetPR.footnote)
        .foregroundStyle(color)
      Spacer(minLength: 0)
    }
    .padding(MeetPRSpacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.md)
        .stroke(color.opacity(0.4), lineWidth: 1)
    }
  }
}

/// Identifiable box so fullScreenCover(item:) can present a PlanningIntent.
private struct PlanningIntentBox: Identifiable {
  let id = UUID()
  let intent: PlanningIntent
}
