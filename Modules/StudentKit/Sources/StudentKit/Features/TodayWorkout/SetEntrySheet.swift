import CoreModels
import DesignSystem
import SwiftUI

/// Juggernaut-style "Performance" entry: tap a set row to open this sheet and
/// dial weight / reps / RPE with big +/- steppers, then mark the set done.
@available(iOS 17.0, macOS 14.0, *)
struct SetEntrySheet: View {
  let rowIndex: Int
  let draft: TodayWorkoutViewModel.SetRowDraft
  let viewModel: TodayWorkoutViewModel
  /// Video attach context (spec 027); nil hides the video block entirely.
  let studentID: UUID?
  let videoViewModel: VideoAttachmentViewModel?
  @Environment(\.dismiss) private var dismiss

  @State private var weight: Decimal
  @State private var reps: Int
  @State private var rpe: Decimal

  init(
    rowIndex: Int,
    draft: TodayWorkoutViewModel.SetRowDraft,
    viewModel: TodayWorkoutViewModel,
    studentID: UUID? = nil,
    videoViewModel: VideoAttachmentViewModel? = nil
  ) {
    self.rowIndex = rowIndex
    self.draft = draft
    self.viewModel = viewModel
    self.studentID = studentID
    self.videoViewModel = videoViewModel
    _weight = State(initialValue: draft.actualWeight ?? draft.prescribed.weightKg ?? 0)
    _reps = State(
      initialValue: draft.actualReps ?? draft.prescribed.reps ?? draft.prescribed.repsMax ?? 0)
    _rpe = State(initialValue: draft.actualRPE ?? draft.prescribed.rpe ?? 8)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(draft.exerciseName)
          .font(.title3.bold())
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text(
          "第 \(draft.prescribed.setIndex + 1) 组 · 目标 "
            + StudentFormatting.prescribed(draft.prescribed)
        )
        .font(.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      }
      .padding(.top, 8)

      stepperRow(
        "重量", value: StudentFormatting.decimal(weight), unit: "kg",
        onDec: { weight = max(0, weight - 2.5) }, onInc: { weight += 2.5 })
      stepperRow(
        "次数", value: "\(reps)", unit: "次",
        onDec: { reps = max(0, reps - 1) }, onInc: { reps += 1 })
      stepperRow(
        "RPE", value: StudentFormatting.decimal(rpe), unit: "",
        onDec: { rpe = max(5, rpe - 0.5) }, onInc: { rpe = min(10, rpe + 0.5) })

      if let videoViewModel, let studentID {
        VideoAttachmentSection(
          studentID: studentID,
          videoViewModel: videoViewModel,
          initialSetLogID: draft.loggedSetID,
          resolveSetLogID: { await viewModel.ensureLoggedSetID(rowIndex: rowIndex) }
        )
      }

      Button {
        save()
      } label: {
        Text(draft.completed ? "保存修改" : "完成本组")
          .font(.headline)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.MeetPR.brandRed)
          .clipShape(.rect(cornerRadius: 12))
      }
      .buttonStyle(.plain)
      .padding(.top, 4)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color.MeetPR.bg)
    .presentationDetents([.medium, .large])
  }

  private func save() {
    viewModel.updateWeight(rowIndex: rowIndex, weight: weight)
    viewModel.updateReps(rowIndex: rowIndex, reps: reps)
    viewModel.updateRPE(rowIndex: rowIndex, rpe: rpe)
    Task { await viewModel.commitSet(rowIndex: rowIndex) }
    dismiss()
  }

  private func stepperRow(
    _ label: String, value: String, unit: String,
    onDec: @escaping () -> Void, onInc: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 12) {
      Text(label)
        .font(.body)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      Spacer()
      stepButton("minus", action: onDec)
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(value)
          .font(.title.monospacedDigit().bold())
          .foregroundStyle(Color.MeetPR.fgPrimary)
        if !unit.isEmpty {
          Text(unit)
            .font(.footnote)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
      }
      .frame(minWidth: 92)
      stepButton("plus", action: onInc)
    }
    .padding(14)
    .background(Color.MeetPR.surface1)
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: 12))
  }

  private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.headline)
        .foregroundStyle(Color.MeetPR.brandRed)
        .frame(width: 40, height: 40)
        .background(Color.MeetPR.brandRedSoft)
        .clipShape(Circle())
    }
    .buttonStyle(.plain)
  }
}
