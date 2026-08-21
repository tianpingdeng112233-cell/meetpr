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
          CoachStudentDetailStrings.text("coach.common.loadFailed"),
          systemImage: "exclamationmark.triangle",
          description: Text(CoachStudentDetailStrings.text("coach.evaluation.summary.loadFailed"))
        )
      case .ready:
        editorForm
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bg)
    .navigationTitle(
      CoachStudentDetailStrings.replacing(
        "coach.evaluation.summary.navigationTitle",
        ["student": viewModel.student.displayName])
    )
    .task {
      if viewModel.state == .loading {
        await viewModel.load()
      }
    }
    .alert(
      CoachStudentDetailStrings.replacing(
        "coach.evaluation.summary.completedAlert",
        ["student": viewModel.student.displayName]),
      isPresented: Bindable(viewModel).showSoftRecommendation
    ) {
      Button(CoachStudentDetailStrings.text("coach.evaluation.summary.later"), role: .cancel) {}
      Button(CoachStudentDetailStrings.text("coach.evaluation.summary.planNow")) {
        Task {
          let profile = await viewModel.fetchPrefillProfile()
          planningIntent = PlanningIntentBox(
            intent: .firstRegularPlan(viewModel.student, profile))
        }
      }
    } message: {
      Text(CoachStudentDetailStrings.text("coach.evaluation.summary.planPrompt"))
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
          noticeCard(notice, color: Color.MeetPR.amber, systemImage: "exclamationmark.triangle")
        }
        if let prefillNotice = viewModel.prefillNotice {
          noticeCard(prefillNotice, color: Color.MeetPR.fgSecondary, systemImage: "info.circle")
        }

        fieldCard(
          title: CoachStudentDetailStrings.text("coach.evaluation.summary.overall"),
          text: Bindable(viewModel).overallAssessment,
          minHeight: 104
        )
        fieldCard(
          title: CoachStudentDetailStrings.text("coach.evaluation.summary.trainingPlan"),
          text: Bindable(viewModel).trainingPlanText,
          minHeight: 104
        )
        fieldCard(
          title: CoachStudentDetailStrings.text("coach.evaluation.summary.words"),
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
    VStack(spacing: 0) {
      if viewModel.isEditMode {
        notifyToggleRow
        PrimaryButton(
          CoachStudentDetailStrings.text("coach.common.save"),
          isDisabled: !viewModel.canSave || viewModel.isSaving,
          isFullWidth: true
        ) {
          Task { _ = await viewModel.save() }
        }
      } else {
        // Mock: a single high-contrast "完成 + 通知学员" primary, with
        // "保存草稿" demoted to a tertiary text action below it.
        PrimaryButton(
          CoachStudentDetailStrings.text("coach.evaluation.summary.completeNotify"),
          isDisabled: !viewModel.canSave || viewModel.isSaving,
          isFullWidth: true
        ) {
          Task { _ = await viewModel.completeAndNotify() }
        }

        Button {
          Task { _ = await viewModel.save() }
        } label: {
          Text(CoachStudentDetailStrings.text("coach.evaluation.summary.saveDraft"))
            .font(.system(size: 14))
            .foregroundStyle(Color.MeetPR.fgTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSave || viewModel.isSaving)
      }
    }
    .padding(.top, MeetPRSpacing.sm)

    if let savedAt = viewModel.lastSavedAt {
      Text(
        CoachStudentDetailStrings.replacing(
          "coach.evaluation.summary.saved",
          ["time": CoachStudentFormatting.relativeText(savedAt)])
      )
      .font(Font.MeetPR.caption)
      .foregroundStyle(Color.MeetPR.fgTertiary)
      .frame(maxWidth: .infinity, alignment: .center)
    }
  }

  /// Edit-mode "同时通知学员" opt-in (D4), restyled as the mock's checkbox row.
  private var notifyToggleRow: some View {
    Button {
      viewModel.notifyOnSave.toggle()
    } label: {
      HStack(spacing: 10) {
        Image(systemName: viewModel.notifyOnSave ? "checkmark" : "")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(Color.white)
          .frame(width: 22, height: 22)
          .background(viewModel.notifyOnSave ? Color.MeetPR.brandRed : Color.MeetPR.surface2)
          .clipShape(.rect(cornerRadius: 5))
          .overlay {
            RoundedRectangle(cornerRadius: 5)
              .stroke(Color.MeetPR.border, lineWidth: viewModel.notifyOnSave ? 0 : 1)
          }
        Text(CoachStudentDetailStrings.text("coach.evaluation.summary.notifyStudent"))
          .font(.system(size: 15))
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Spacer()
      }
      .padding(.bottom, 14)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(CoachStudentDetailStrings.text("coach.evaluation.summary.notifyStudent"))
    .accessibilityValue(
      CoachStudentDetailStrings.text(
        viewModel.notifyOnSave ? "coach.common.selected" : "coach.common.notSelected"))
  }

  // MARK: - Building blocks

  private func fieldCard(title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Text(title)
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.brandRed)

      TextEditor(text: text)
        .frame(minHeight: minHeight)
        .scrollContentBackground(.hidden)
        .padding(MeetPRSpacing.md)
        .background(Color.MeetPR.surface1)
        .clipShape(.rect(cornerRadius: MeetPRRadius.md))
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.md)
            .stroke(Color.MeetPR.border, lineWidth: 1)
        }
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

  private func noticeCard(_ message: String, color: Color, systemImage: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
      Image(systemName: systemImage)
        .font(.system(size: 14))
        .foregroundStyle(color)
      Text(message)
        .font(Font.MeetPR.footnote)
        .foregroundStyle(color)
      Spacer(minLength: 0)
    }
    .padding(MeetPRSpacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surface1)
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
