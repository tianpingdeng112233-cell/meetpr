import CoreModels
import DesignSystem
import SwiftUI

/// Workbench entry for plan import (spec 043 §E1). Shown greyed-out and inert
/// while `PlanImportCapability.isEnabled` is false — in-app import is frozen in
/// favour of the web plan editor, which owns xlsx parsing. When enabled, tapping
/// opens the flow: pick a student, then the import-review sheet for that student.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct ImportEntryButton: View {
  let repository: any PlanRepository
  var now: @Sendable () -> Date = { Date() }
  var onPublished: () -> Void = {}

  @State private var isPresenting = false

  var body: some View {
    SecondaryButton("导入计划", isDisabled: !PlanImportCapability.isEnabled, isFullWidth: true) {
      isPresenting = true
    }
    .sheet(isPresented: $isPresenting) {
      ImportFlowView(
        repository: repository,
        now: now,
        onPublished: {
          isPresenting = false
          onPublished()
        },
        onCancel: { isPresenting = false }
      )
    }
  }
}

/// Student pick → review. Kept separate so the review view model is built only
/// once a student is chosen (it is student-scoped).
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct ImportFlowView: View {
  let repository: any PlanRepository
  var now: @Sendable () -> Date = { Date() }
  var onPublished: () -> Void = {}
  var onCancel: () -> Void = {}

  @State private var students: [CoachStudentSummary] = []
  @State private var selected: CoachStudentSummary?
  @State private var loadError: String?

  var body: some View {
    NavigationStack {
      Group {
        if let selected {
          ImportReviewSheet(
            viewModel: ImportReviewViewModel(student: selected, repository: repository, now: now),
            onPublished: onPublished,
            onCancel: onCancel
          )
        } else {
          studentPicker
        }
      }
    }
    .task {
      do {
        students = try await repository.fetchStudents()
      } catch {
        loadError = error.localizedDescription
      }
    }
  }

  private var studentPicker: some View {
    List {
      if let loadError {
        Text("学员加载失败：\(loadError)")
          .font(.footnote)
          .foregroundStyle(Color.MeetPR.gold500)
      }
      Section("选学员") {
        ForEach(students) { student in
          Button {
            selected = student
          } label: {
            Text(student.displayName)
              .foregroundStyle(Color.MeetPR.textPrimary)
          }
        }
      }
    }
    .navigationTitle("导入计划")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("取消") { onCancel() }
      }
    }
  }
}
