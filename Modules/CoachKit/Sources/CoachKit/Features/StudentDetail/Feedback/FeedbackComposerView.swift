import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Coach text-feedback composer, reskinned to the `DKCoachVideoFeedback`
/// mock's “文本反馈” surface: a custom large-title header, a card-surfaced
/// editor with a placeholder, and a bordered “关联” card holding the day /
/// exercise pickers. The Form is replaced by a ScrollView of
/// Color.MeetPR.surface1 cards (RoundedRectangle stroke Color.MeetPR.border,
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
      VStack(spacing: 0) {
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
      .background(Color.MeetPR.bg)
      .toolbar(.hidden, for: .navigationBar)
      .safeAreaInset(edge: .bottom) {
        sendBar
      }
    }
  }

  // MARK: - Header (cancel · large title)

  private var header: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Eyebrow("文本反馈 //")
        Spacer()
        Button("取消") {
          dismiss()
        }
        .font(.system(size: 16))
        .foregroundStyle(Color.MeetPR.fgSecondary)
      }
      Text("给 \(studentName) 写反馈")
        .font(.system(size: 28, weight: .heavy))
        .foregroundStyle(Color.MeetPR.fgPrimary)
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
        .background(Color.MeetPR.surface1)
        .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.lg)
            .stroke(Color.MeetPR.border, lineWidth: 1)
        }
    }
  }

  private var editor: some View {
    ZStack(alignment: .topLeading) {
      if viewModel.text.isEmpty {
        Text("给 \(studentName) 写反馈...")
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.fgTertiary)
          .padding(.top, 8)
          .padding(.leading, 5)
      }
      TextEditor(text: $viewModel.text)
        .font(Font.MeetPR.body)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .scrollContentBackground(.hidden)
    }
  }

  // MARK: - 关联 card (day + exercise pickers)

  private var linkCard: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      sectionLabel("关联")
      VStack(spacing: 0) {
        dayRow
        Rectangle().fill(Color.MeetPR.border).frame(height: 1)
        exerciseRow
      }
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(Color.MeetPR.border, lineWidth: 1)
      }
    }
  }

  private var dayRow: some View {
    HStack {
      Text("日期")
        .font(.system(size: 16))
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Spacer()
      Picker("日期", selection: $viewModel.selectedDayDate) {
        Text("不关联").tag(Date?.none)
        ForEach(days) { day in
          Text(CoachStudentFormatting.fullDateText(day.date)).tag(Optional(day.date))
        }
      }
      .labelsHidden()
      .tint(Color.MeetPR.fgPrimary)
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
        .font(.system(size: 16))
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Spacer()
      Picker("动作", selection: $viewModel.selectedExerciseID) {
        Text("不关联").tag(UUID?.none)
        ForEach(viewModel.availableExercises(days: days)) { exercise in
          Text(exercise.exercise.name).tag(Optional(exercise.id))
        }
      }
      .labelsHidden()
      .tint(Color.MeetPR.fgPrimary)
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.vertical, MeetPRSpacing.md)
    .frame(minHeight: 52)
  }

  // MARK: - Failure banner

  private func failureBanner(_ message: String) -> some View {
    Label(message, systemImage: "exclamationmark.triangle")
      .font(Font.MeetPR.footnote)
      .foregroundStyle(Color.MeetPR.amber)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.md)
      .background(Color.MeetPR.amberSoft)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
  }

  // MARK: - Send bar (mock's filled dark primary action)

  private var sendBar: some View {
    Button {
      Task {
        guard let item = await viewModel.send() else { return }
        onSent(item)
        dismiss()
      }
    } label: {
      HStack(spacing: MeetPRSpacing.sm) {
        Image(systemName: "paperplane.fill")
        Text("发送")
      }
      .font(.system(size: 16, weight: .semibold))
      .foregroundStyle(viewModel.canSend ? Color.MeetPR.bg : Color.MeetPR.fgTertiary)
      .frame(maxWidth: .infinity)
      .frame(height: 50)
      .background(viewModel.canSend ? Color.MeetPR.fgPrimary : Color.MeetPR.surface2)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(.plain)
    .disabled(!viewModel.canSend)
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.top, MeetPRSpacing.sm)
    .padding(.bottom, MeetPRSpacing.sm)
    .background(.ultraThinMaterial)
    .accessibilityLabel("发送")
  }

  // MARK: - Building blocks

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(Font.MeetPR.monoLabel)
      .tracking(Font.MeetPR.monoLabelTracking)
      .foregroundStyle(Color.MeetPR.fgSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
