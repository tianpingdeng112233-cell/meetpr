import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Coach text-feedback composer, reskinned to the `DKCoachVideoFeedback`
/// mock's “文本反馈” surface: a custom large-title header, a card-surfaced
/// editor with a placeholder, and a bordered “关联” card holding the day /
/// exercise pickers. The Form is replaced by a ScrollView of
/// Color.MeetPR.surfaceCard cards (RoundedRectangle stroke Color.MeetPR.borderDefault,
/// MeetPRRadius.lg) with Font.MeetPR.monoLabel section labels.
///
/// All behavior is preserved verbatim: the editor binds `$viewModel.text`,
/// both pickers bind `$viewModel.selectedDayDate` / `$viewModel.selectedExerciseID`
/// with the same `onChange` → `reconcileExerciseSelection(days:)` and the same
/// `availableExercises(days:)` source, the failed state renders
/// `viewModel.state`, 取消 calls `dismiss()`, and 发送 awaits `viewModel.send()`
/// then `onSent(item)` + `dismiss()` gated by `viewModel.canSend`.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct FeedbackComposerView: View {
  @Bindable private var viewModel: FeedbackComposerViewModel
  private let studentName: String
  private let days: [StudentPlanDay]
  private let onSent: (CoachFeedback) -> Void
  @Environment(\.dismiss) private var dismiss

  init(
    studentID: UUID,
    studentName: String,
    days: [StudentPlanDay],
    repository: any StudentFeedbackRepository,
    onSent: @escaping (CoachFeedback) -> Void
  ) {
    viewModel = FeedbackComposerViewModel(studentID: studentID, repository: repository)
    self.studentName = studentName
    self.days = days
    self.onSent = onSent
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: MeetPRSpacing.zero) {
        header

        ScrollView {
          VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
            editorCard
            linkCard

            if case .failed(let message) = viewModel.state {
              failureBanner(message)
            }
          }
          .padding(MeetPRSpacing.base)
        }
        .scrollContentBackground(.hidden)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bgBase)
      .hideNavigationBar()
      .safeAreaInset(edge: .bottom) {
        sendBar
      }
    }
  }

  // MARK: - Header (cancel · large title)

  private var header: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      HStack {
        Eyebrow("文本反馈 //")
        Spacer()
        Button("取消") {
          dismiss()
        }
        .font(.MeetPR.system(size: MeetPRFontMetrics.size16))
        .foregroundStyle(Color.MeetPR.textSecondary)
      }
      Text("给 \(studentName) 写反馈")
        .font(.MeetPR.display(size: 28, weight: .extraBold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.top, MeetPRSpacing.sm)
    .padding(.bottom, MeetPRSpacing.xs)
  }

  // MARK: - Editor card

  private var editorCard: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      sectionLabel("反馈内容")
      editor
        .frame(minHeight: 180)
        .padding(MeetPRSpacing.md)
        .background(Color.MeetPR.surfaceCard)
        .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.lg)
            .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
        }
    }
  }

  private var editor: some View {
    ZStack(alignment: .topLeading) {
      if viewModel.text.isEmpty {
        Text("给 \(studentName) 写反馈...")
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.textTertiary)
          .padding(.top, MeetPRSpacing.space2)
          .padding(.leading, MeetPRSpacing.point5)
      }
      TextEditor(text: $viewModel.text)
        .font(Font.MeetPR.body)
        .foregroundStyle(Color.MeetPR.textPrimary)
        .scrollContentBackground(.hidden)
    }
  }

  // MARK: - 关联 card (day + exercise pickers)

  private var linkCard: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      sectionLabel("关联")
      VStack(spacing: MeetPRSpacing.zero) {
        dayRow
        Rectangle().fill(Color.MeetPR.borderDefault).frame(height: 1)
        exerciseRow
      }
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
      }
    }
  }

  private var dayRow: some View {
    HStack {
      Text("日期")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size16))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Spacer()
      Picker("日期", selection: $viewModel.selectedDayDate) {
        Text("不关联").tag(Date?.none)
        ForEach(days) { day in
          Text(CoachStudentFormatting.fullDateText(day.date)).tag(Optional(day.date))
        }
      }
      .labelsHidden()
      .tint(Color.MeetPR.textPrimary)
      .onChange(of: viewModel.selectedDayDate) { _, _ in
        viewModel.reconcileExerciseSelection(days: days)
      }
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.vertical, MeetPRSpacing.md)
    .frame(minHeight: 52)
  }

  private var exerciseRow: some View {
    HStack {
      Text("动作")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size16))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Spacer()
      Picker("动作", selection: $viewModel.selectedExerciseID) {
        Text("不关联").tag(UUID?.none)
        ForEach(viewModel.availableExercises(days: days)) { exercise in
          Text(exercise.exercise.name).tag(Optional(exercise.id))
        }
      }
      .labelsHidden()
      .tint(Color.MeetPR.textPrimary)
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.vertical, MeetPRSpacing.md)
    .frame(minHeight: 52)
  }

  // MARK: - Failure banner

  private func failureBanner(_ message: String) -> some View {
    Label(message, systemImage: "exclamationmark.triangle")
      .font(Font.MeetPR.footnote)
      .foregroundStyle(Color.MeetPR.gold500)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.md)
      .background(Color.MeetPR.goldSoft)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
  }

  // MARK: - Send bar (mock's filled dark primary action)

  private var sendBar: some View {
    BrandPrimaryButton(
      "发送",
      systemImage: "paperplane.fill",
      isDisabled: !viewModel.canSend,
      isFullWidth: true
    ) {
      Task {
        guard let item = await viewModel.send() else { return }
        onSent(item)
        dismiss()
      }
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.top, MeetPRSpacing.sm)
    .padding(.bottom, MeetPRSpacing.sm)
    .background(Color.MeetPR.bgBase)
    .accessibilityLabel("发送")
  }

  // MARK: - Building blocks

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(Font.MeetPR.monoLabel)
      .tracking(Font.MeetPR.monoLabelTracking)
      .foregroundStyle(Color.MeetPR.textSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
