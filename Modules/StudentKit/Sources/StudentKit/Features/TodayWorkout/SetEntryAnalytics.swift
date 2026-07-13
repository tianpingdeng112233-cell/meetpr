import Analytics
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct SetEntryAnalyticsModifier: ViewModifier {
  let weightText: String
  let repsText: String
  let rpeText: String
  let focusedField: SetEntryNumberField?

  @State private var weightTracker = SetEntryFieldEditTracker()
  @State private var repsTracker = SetEntryFieldEditTracker()
  @State private var rpeTracker = SetEntryFieldEditTracker()

  func body(content: Content) -> some View {
    content
      .onChange(of: focusedField) { oldField, newField in
        if let oldField {
          finishEditing(oldField)
        }
        if let newField {
          beginEditing(newField)
        }
      }
  }

  private func beginEditing(_ field: SetEntryNumberField) {
    switch field {
    case .weight: weightTracker.begin(value: weightText)
    case .reps: repsTracker.begin(value: repsText)
    case .rpe: rpeTracker.begin(value: rpeText)
    }
  }

  private func finishEditing(_ field: SetEntryNumberField) {
    let count: Int?
    let analyticsField: AnalyticsField
    switch field {
    case .weight:
      count = weightTracker.finish(value: weightText)
      analyticsField = .weight
    case .reps:
      count = repsTracker.finish(value: repsText)
      analyticsField = .reps
    case .rpe:
      count = rpeTracker.finish(value: rpeText)
      analyticsField = .rpe
    }
    if let count { record(field: analyticsField, count: count) }
  }

  private func record(field: AnalyticsField, count: Int) {
    FrictionFeedbackController.shared.recordReEdit(
      flow: .recordSet,
      field: field,
      count: count,
      fromScreen: .todayWorkout)
  }
}

struct SetEntryFieldEditTracker: Sendable {
  private var baseline: String?
  private var completedEditCount = 0

  mutating func begin(value: String) {
    baseline = value
  }

  mutating func finish(value: String) -> Int? {
    guard let baseline else { return nil }
    self.baseline = nil
    guard value != baseline else { return nil }
    completedEditCount += 1
    return completedEditCount >= 2 ? completedEditCount : nil
  }
}

@MainActor
enum SetEntryAnalytics {
  static func trackCancel() {
    Analytics.shared.navigationBack(from: .todayWorkout, in: .recordSet)
    FrictionFeedbackController.shared.recordFlowCancel(
      flow: .recordSet, fromScreen: .todayWorkout)
  }

  static func trackCommit(
    draft: TodayWorkoutViewModel.SetRowDraft,
    videoViewModel: VideoAttachmentViewModel?,
    failed: Bool
  ) {
    let hasVideo = draft.loggedSetID.flatMap { videoViewModel?.rowStates[$0] } != nil
    Analytics.shared.setLogged(
      exerciseID: draft.exerciseID,
      setIndex: draft.prescribed.setIndex,
      hasVideo: hasVideo,
      outcome: failed ? .failed : .completed)
  }
}
