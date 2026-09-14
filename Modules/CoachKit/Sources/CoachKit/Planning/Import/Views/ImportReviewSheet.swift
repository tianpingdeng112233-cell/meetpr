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
    .background(Color.MeetPR.bg)
    .navigationTitle(CoachImportStrings.title)
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button(CoachPlanningStrings.cancel) { onCancel() }
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
    VStack(spacing: 16) {
      Text(CoachImportStrings.pickFileDescription)
        .font(.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)
        .multilineTextAlignment(.center)
      PrimaryButton(CoachImportStrings.selectXLSXFile, isFullWidth: true) {
        isImporting = true
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var reviewState: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        summaryHeader
        startDatePicker
        ForEach($viewModel.weeks) { $week in
          weekCard($week)
        }
        publishBar
      }
      .padding(16)
    }
  }

  private var summaryHeader: some View {
    VStack(alignment: .leading, spacing: 4) {
      Eyebrow(CoachImportStrings.review)
      Text(
        CoachImportStrings.summary(
          parsed: viewModel.weeks.count,
          selected: viewModel.selectedWeekCount
        )
      )
      .font(.subheadline.bold())
      .foregroundStyle(Color.MeetPR.fgPrimary)
      TextField(CoachImportStrings.planName, text: $viewModel.planName)
        .font(.footnote)
        .textFieldStyle(.roundedBorder)
    }
  }

  private var startDatePicker: some View {
    DatePicker(
      CoachImportStrings.startDate,
      selection: $viewModel.startDate,
      displayedComponents: .date
    )
    .font(.footnote)
  }

  private func weekCard(_ week: Binding<ImportReviewWeek>) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Button {
        viewModel.toggleWeek(week.wrappedValue.id)
      } label: {
        HStack(spacing: 8) {
          Image(systemName: week.wrappedValue.isSelected ? "checkmark.square.fill" : "square")
            .foregroundStyle(
              week.wrappedValue.isSelected ? Color.MeetPR.brandRed : Color.MeetPR.fgSecondary)
          Text(CoachImportStrings.sourceWeek(week.wrappedValue.blockIndex + 1))
            .font(.subheadline.bold())
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Spacer()
        }
      }

      if week.wrappedValue.isSelected {
        ForEach(week.days) { $day in
          dayBlock($day)
        }
      }
    }
    .padding(14)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1)
    }
  }

  private func dayBlock(_ day: Binding<ImportReviewDay>) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(CoachImportStrings.day(day.wrappedValue.dayOfWeek + 1))
        .font(Font.MeetPR.monoLabel)
        .foregroundStyle(Color.MeetPR.brandRed)
      ForEach(day.exercises) { $exercise in
        VStack(alignment: .leading, spacing: 8) {
          ExerciseMatchSection(
            exercise: $exercise,
            candidates: viewModel.candidates(for: exercise.id),
            boundName: viewModel.boundExerciseName(exercise.boundExerciseID)
          )
          ForEach($exercise.sets) { $set in
            IntensityReviewSection(set: $set)
          }
        }
        .padding(.vertical, 6)
      }
    }
  }

  private var publishBar: some View {
    VStack(spacing: 8) {
      if !viewModel.canPublish {
        Text(CoachImportStrings.incompleteHint)
          .font(.caption)
          .foregroundStyle(Color.MeetPR.amber)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      PrimaryButton(
        CoachImportStrings.publishToStudent,
        isDisabled: !viewModel.canPublish,
        isFullWidth: true
      ) {
        Task {
          await viewModel.publish()
          if viewModel.phase == .published { onPublished() }
        }
      }
    }
  }

  private var publishedState: some View {
    VStack(spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .font(.largeTitle)
        .foregroundStyle(Color.MeetPR.green)
      Text(CoachImportStrings.publishedTo(viewModel.student.displayName))
        .font(.subheadline.bold())
        .foregroundStyle(Color.MeetPR.fgPrimary)
      SecondaryButton(CoachPlanningStrings.done) { onPublished() }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(20)
  }

  private func failedState(_ message: String) -> some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.largeTitle)
        .foregroundStyle(Color.MeetPR.amber)
      Text(message)
        .font(.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)
        .multilineTextAlignment(.center)
      SecondaryButton(CoachImportStrings.chooseAnotherFile) {
        viewModel.phase = .pickFile
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(20)
  }
}
