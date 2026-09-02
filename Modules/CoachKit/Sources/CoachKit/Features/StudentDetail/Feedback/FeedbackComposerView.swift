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
      .hideNavigationBar()
      .safeAreaInset(edge: .bottom) {
        sendBar
      }
    }
  }

  // MARK: - Header (cancel · large title)

  private var header: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Eyebrow(CoachStudentDetailStrings.text("coach.feedback.eyebrow"))
        Spacer()
        Button(CoachStudentDetailStrings.text("coach.common.cancel")) {
          dismiss()
        }
        .font(.system(size: 16))
        .foregroundStyle(Color.MeetPR.fgSecondary)
      }
      Text(
        CoachStudentDetailStrings.replacing(
          "coach.feedback.title", ["student": studentName])
      )
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
      sectionLabel(CoachStudentDetailStrings.text("coach.feedback.content"))
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
        Text(
          CoachStudentDetailStrings.replacing(
            "coach.feedback.placeholder", ["student": studentName])
        )
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
      sectionLabel(CoachStudentDetailStrings.text("coach.feedback.link"))
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
      Text(CoachStudentDetailStrings.text("coach.feedback.date"))
        .font(.system(size: 16))
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Spacer()
      Picker(
        CoachStudentDetailStrings.text("coach.feedback.date"), selection: $viewModel.selectedDayDate
      ) {
        Text(CoachStudentDetailStrings.text("coach.feedback.notLinked")).tag(Date?.none)
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
      Text(CoachStudentDetailStrings.text("coach.feedback.exercise"))
        .font(.system(size: 16))
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Spacer()
      Picker(
        CoachStudentDetailStrings.text("coach.feedback.exercise"),
        selection: $viewModel.selectedExerciseID
      ) {
        Text(CoachStudentDetailStrings.text("coach.feedback.notLinked")).tag(UUID?.none)
        ForEach(viewModel.availableExercises(days: days)) { exercise in
          Text(CoachLocalization.exerciseName(exercise.exercise)).tag(Optional(exercise.id))
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
        Text(CoachStudentDetailStrings.text("coach.feedback.send"))
      }
      .font(.system(size: 16, weight: .semibold))
      .foregroundStyle(viewModel.canSend ? Color.MeetPR.bg : Color.MeetPR.fgTertiary)
      .frame(maxWidth: .infinity)
      .frame(height: 50)
      .background(viewModel.canSend ? Color.MeetPR.fgPrimary : Color.MeetPR.surface2)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .disabled(!viewModel.canSend)
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.top, MeetPRSpacing.sm)
    .padding(.bottom, MeetPRSpacing.sm)
    .background(.ultraThinMaterial)
    .accessibilityLabel(CoachStudentDetailStrings.text("coach.feedback.send"))
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
