import CoreModels
import DesignSystem
import SwiftUI
import UniformTypeIdentifiers

/// Import-review sheet (spec 043 §E), independent of the planning-workspace
/// editor. Flow: pick xlsx → select weeks + start day → bind exercises → fill
/// values → publish. Parsing is local; the file never leaves the device.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct ImportReviewSheet: View {
  @Bindable var viewModel: ImportReviewViewModel
  var onPublished: () -> Void = {}
  var onCancel: () -> Void = {}

  @State private var isImporting = false

  private static let xlsxType = UTType(filenameExtension: "xlsx") ?? .spreadsheet

  var body: some View {
    Group {
      switch viewModel.phase {
      case .pickFile:
        pickFileState
      case .parsing, .publishing:
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      case .review:
        reviewState
      case .published:
        publishedState
      case .failed(let message):
        failedState(message)
      }
    }
    .background(Color.MeetPR.bgBase)
    .navigationTitle("导入计划")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("取消") { onCancel() }
      }
    }
    .fileImporter(
      isPresented: $isImporting,
      allowedContentTypes: [Self.xlsxType],
      allowsMultipleSelection: false
    ) { result in
      guard case .success(let urls) = result, let url = urls.first else { return }
      Task { await viewModel.parse(fileURL: url) }
    }
  }

  // MARK: - states

  private var pickFileState: some View {
    VStack(spacing: MeetPRSpacing.space4) {
      Text("把电脑上的 .xlsx 计划表 AirDrop 到手机，选它导入。解析在本机完成，文件不上传。")
        .font(.footnote)
        .foregroundStyle(Color.MeetPR.textSecondary)
        .multilineTextAlignment(.center)
      PrimaryButton("选择 .xlsx 文件", isFullWidth: true) {
        isImporting = true
      }
    }
    .padding(MeetPRSpacing.space5)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var reviewState: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space4) {
        summaryHeader
        startDatePicker
        ForEach($viewModel.weeks) { $week in
          weekCard($week)
        }
        publishBar
      }
      .padding(MeetPRSpacing.space4)
    }
  }

  private var summaryHeader: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      Eyebrow("导入审阅")
      Text("共解析出 \(viewModel.weeks.count) 周 · 选中 \(viewModel.selectedWeekCount) 周")
        .font(.subheadline.bold())
        .foregroundStyle(Color.MeetPR.textPrimary)
      TextField("计划名", text: $viewModel.planName)
        .font(.footnote)
        .textFieldStyle(.roundedBorder)
    }
  }

  private var startDatePicker: some View {
    DatePicker(
      "开始日（默认下周一）",
      selection: $viewModel.startDate,
      displayedComponents: .date
    )
    .font(.footnote)
  }

  private func weekCard(_ week: Binding<ImportReviewWeek>) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
      Button {
        viewModel.toggleWeek(week.wrappedValue.id)
      } label: {
        HStack(spacing: MeetPRSpacing.space2) {
          Image(systemName: week.wrappedValue.isSelected ? "checkmark.square.fill" : "square")
            .foregroundStyle(
              week.wrappedValue.isSelected ? Color.MeetPR.gold500 : Color.MeetPR.textSecondary)
          Text("原表第 \(week.wrappedValue.blockIndex + 1) 周")
            .font(.subheadline.bold())
            .foregroundStyle(Color.MeetPR.textPrimary)
          Spacer()
        }
      }
      .buttonStyle(PressScaleButtonStyle())

      if week.wrappedValue.isSelected {
        ForEach(week.days) { $day in
          dayBlock($day)
        }
      }
    }
    .padding(MeetPRSpacing.point14)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.control).stroke(
        Color.MeetPR.borderDefault, lineWidth: 1)
    }
  }

  private func dayBlock(_ day: Binding<ImportReviewDay>) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point10) {
      Text("第 \(day.wrappedValue.dayOfWeek + 1) 天")
        .font(Font.MeetPR.monoLabel)
        .foregroundStyle(Color.MeetPR.gold500)
      ForEach(day.exercises) { $exercise in
        VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
          ExerciseMatchSection(
            exercise: $exercise,
            candidates: viewModel.candidates(for: exercise.id),
            boundName: viewModel.boundExerciseName(exercise.boundExerciseID)
          )
          ForEach($exercise.sets) { $set in
            IntensityReviewSection(set: $set)
          }
        }
        .padding(.vertical, MeetPRSpacing.point6)
      }
    }
  }

  private var publishBar: some View {
    VStack(spacing: MeetPRSpacing.space2) {
      if !viewModel.canPublish {
        Text("还有「待你定」的项——补齐重量/RPE、绑定动作后才能发布。")
          .font(.caption)
          .foregroundStyle(Color.MeetPR.gold500)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      PrimaryButton("发布给学员", isDisabled: !viewModel.canPublish, isFullWidth: true) {
        Task {
          await viewModel.publish()
          if viewModel.phase == .published { onPublished() }
        }
      }
    }
  }

  private var publishedState: some View {
    VStack(spacing: MeetPRSpacing.space3) {
      Image(systemName: "checkmark.circle.fill")
        .font(.largeTitle)
        .foregroundStyle(Color.MeetPR.success)
      Text("已发布给 \(viewModel.student.displayName)")
        .font(.subheadline.bold())
        .foregroundStyle(Color.MeetPR.textPrimary)
      SecondaryButton("完成") { onPublished() }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(MeetPRSpacing.space5)
  }

  private func failedState(_ message: String) -> some View {
    VStack(spacing: MeetPRSpacing.space3) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.largeTitle)
        .foregroundStyle(Color.MeetPR.gold500)
      Text(message)
        .font(.footnote)
        .foregroundStyle(Color.MeetPR.textSecondary)
        .multilineTextAlignment(.center)
      SecondaryButton("重新选择文件") {
        viewModel.phase = .pickFile
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(MeetPRSpacing.space5)
  }
}
