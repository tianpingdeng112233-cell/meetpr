import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

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
      Form {
        Section {
          editor
            .frame(minHeight: 160)
        } header: {
          Text("给 \(studentName) 写反馈")
        }

        Section("关联") {
          Picker("日期", selection: $viewModel.selectedDayDate) {
            Text("不关联").tag(Date?.none)
            ForEach(days) { day in
              Text(CoachStudentFormatting.fullDateText(day.date)).tag(Optional(day.date))
            }
          }
          .onChange(of: viewModel.selectedDayDate) { _, _ in
            viewModel.reconcileExerciseSelection(days: days)
          }

          Picker("动作", selection: $viewModel.selectedExerciseID) {
            Text("不关联").tag(UUID?.none)
            ForEach(viewModel.availableExercises(days: days)) { exercise in
              Text(exercise.exercise.name).tag(Optional(exercise.id))
            }
          }
        }

        if case .failed(let message) = viewModel.state {
          Section {
            Label(message, systemImage: "exclamationmark.triangle")
              .foregroundStyle(Color.MeetPR.amber)
          }
        }
      }
      .navigationTitle("写反馈")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task {
              guard let item = await viewModel.send() else { return }
              onSent(item)
              dismiss()
            }
          } label: {
            Label("发送", systemImage: "paperplane.fill")
          }
          .disabled(!viewModel.canSend)
        }
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
        .scrollContentBackground(.hidden)
    }
  }
}
