import CoreModels
import DesignSystem
import Foundation

struct TodayWorkoutProgress: Equatable, Sendable {
  let remainingSets: Int
  let remainingExercises: Int
  let currentSetNumber: Int
  let currentSetTotal: Int
  let currentExerciseNumber: Int
  let exerciseTotal: Int
  let allDone: Bool

  init(day: StudentPlanDay, drafts: [TodayWorkoutViewModel.SetRowDraft]) {
    let active = drafts.first { !$0.completed }
    let current = active ?? drafts.last
    let exerciseIDs = day.exercises.map(\.id)
    let currentExerciseIndex =
      current.flatMap { draft in exerciseIDs.firstIndex(of: draft.planExerciseID) }
      ?? max(exerciseIDs.count - 1, 0)
    let exerciseDrafts =
      current.map { draft in
        drafts.filter { $0.planExerciseID == draft.planExerciseID }
      } ?? []
    let currentSetIndex =
      current.flatMap { draft in exerciseDrafts.firstIndex { $0.id == draft.id } }
      ?? max(exerciseDrafts.count - 1, 0)

    self.remainingSets = drafts.filter { !$0.completed }.count
    self.remainingExercises =
      day.exercises.filter { exercise in
        drafts.contains { $0.planExerciseID == exercise.id && !$0.completed }
      }.count
    self.currentSetNumber = min(currentSetIndex + 1, max(exerciseDrafts.count, 1))
    self.currentSetTotal = exerciseDrafts.count
    self.currentExerciseNumber = min(currentExerciseIndex + 1, max(exerciseIDs.count, 1))
    self.exerciseTotal = exerciseIDs.count
    self.allDone = !drafts.isEmpty && drafts.allSatisfy(\.completed)
  }

  var remainingText: String {
    "还有 \(remainingExercises) 个动作 · \(remainingSets) 组未记录"
  }

  var positionText: String {
    "第 \(currentSetNumber) / \(currentSetTotal) 组 · "
      + "动作 \(currentExerciseNumber) / \(exerciseTotal)"
  }
}

struct TodayWorkoutPresentation: Equatable, Sendable {
  enum HeroMode: Equatable, Sendable {
    case list
    case recording
  }

  struct Exercise: Equatable, Sendable, Identifiable {
    let id: UUID
    let stableIndex: Int
    let name: String
    let reference: String
    let note: String
    let rows: [Row]

    var allRecorded: Bool {
      !rows.isEmpty && rows.allSatisfy { $0.record.status != .pending }
    }
  }

  struct Row: Equatable, Sendable, Identifiable {
    let id: UUID
    let stableIndex: Int
    let record: ExerciseSetRecord
    let draft: TodayWorkoutViewModel.SetRowDraft
  }

  let day: StudentPlanDay
  let heroMode: HeroMode
  let exercises: [Exercise]
  let progress: TodayWorkoutProgress
  let currentRow: Row?

  init(
    day: StudentPlanDay,
    drafts: [TodayWorkoutViewModel.SetRowDraft],
    references: [UUID: ExerciseReference],
    videoStates: [UUID: SetRow.VideoState] = [:],
    started: Bool
  ) {
    let hasRecordedSet = drafts.contains(where: \.completed)
    self.day = day
    self.heroMode = !started && !hasRecordedSet ? .list : .recording
    self.progress = TodayWorkoutProgress(day: day, drafts: drafts)

    self.exercises = day.exercises.enumerated().map { exerciseIndex, exercise in
      let rows = drafts.filter { $0.planExerciseID == exercise.id }.map { draft in
        return Row(
          id: draft.id,
          stableIndex: drafts.firstIndex { $0.id == draft.id } ?? 0,
          record: Self.record(
            from: draft,
            index: SetDisplayNumber.number(for: draft),
            videoState: draft.loggedSetID.flatMap { videoStates[$0] } ?? .none
          ),
          draft: draft
        )
      }
      return Exercise(
        id: exercise.id,
        stableIndex: exerciseIndex,
        name: exercise.exercise.name,
        reference: Self.referenceText(references[exercise.exercise.id]),
        note: CoachNoteDisplay.text(exercise.notes) ?? "",
        rows: rows
      )
    }
    self.currentRow =
      exercises.flatMap(\.rows).first { !$0.draft.completed }
      ?? exercises.flatMap(\.rows).last
  }

  static func record(
    from draft: TodayWorkoutViewModel.SetRowDraft,
    index: Int,
    videoState: SetRow.VideoState
  ) -> ExerciseSetRecord {
    ExerciseSetRecord(
      index: index,
      weight: optionalDecimalDouble(draft.actualWeight ?? draft.prescribed.weightKg),
      reps: draft.actualReps ?? draft.prescribed.reps ?? draft.prescribed.repsMax ?? 0,
      rpe: decimalDouble(draft.actualRPE ?? draft.prescribed.rpe ?? 0),
      status: draft.failed ? .failed : (draft.completed ? .done : .pending),
      videoState: videoState,
      indexAccessibilityIdentifier: "todayWorkout.set.\(draft.id.uuidString).number"
    )
  }

  private static func referenceText(_ reference: ExerciseReference?) -> String {
    guard let reference else { return "" }
    var parts: [String] = []
    if let last = reference.last {
      parts.append("上次 \(numberText(last.weightKg))kg×\(last.reps)")
    }
    if let best = reference.best {
      parts.append("最佳 \(numberText(best.weightKg))kg×\(best.reps)")
    }
    return parts.joined(separator: " · ")
  }

  private static func optionalDecimalDouble(_ value: Decimal?) -> Double? {
    value.map { NSDecimalNumber(decimal: $0).doubleValue }
  }

  private static func decimalDouble(_ value: Decimal?) -> Double {
    optionalDecimalDouble(value) ?? 0
  }

  private static func numberText(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)))
  }
}

enum TodayWorkoutContentPolicy {
  static func isRestDay(_ day: StudentPlanDay) -> Bool {
    day.exercises.isEmpty
  }
}

struct TrainingCalendarScrollState: Equatable, Sendable {
  static let collapseOffset: CGFloat = 56
  static let expandOffset: CGFloat = 6
  static let minimumSlack: CGFloat = 200

  let isOpen: Bool

  func updating(offset: CGFloat, contentSlack: CGFloat) -> Self {
    if isOpen, contentSlack > Self.minimumSlack, offset > Self.collapseOffset {
      return Self(isOpen: false)
    }
    if !isOpen, offset < Self.expandOffset {
      return Self(isOpen: true)
    }
    return self
  }
}
