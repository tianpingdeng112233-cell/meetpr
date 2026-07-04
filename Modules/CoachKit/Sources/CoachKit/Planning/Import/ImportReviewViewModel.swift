import CoreModels
import Foundation

// Drives the import-review flow (spec 043 §E): load students + catalog, parse a
// chosen xlsx locally, let the coach pick weeks / bind exercises / fill values,
// then assemble a published entity tree and publish via the repository. Never
// touches the draft store.

@MainActor
@Observable
final class ImportReviewViewModel {
  enum Phase: Equatable {
    case pickFile
    case parsing
    case review
    case publishing
    case published
    case failed(String)
  }

  /// Sheets that are never plan pages (spec 043 §A 不解析).
  static let ignoredSheetNames: Set<String> = ["注意事项", "2026"]

  private let repository: any PlanRepository
  private let now: @Sendable () -> Date
  private let assembler: ImportPlanAssembler

  let student: CoachStudentSummary
  var phase: Phase = .pickFile
  var planName: String
  var startDate: Date
  var weeks: [ImportReviewWeek] = []
  private(set) var catalog: [Exercise] = []

  init(
    student: CoachStudentSummary,
    repository: any PlanRepository,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.student = student
    self.repository = repository
    self.now = now
    assembler = ImportPlanAssembler(now: now)
    planName = "\(student.displayName) 导入计划"
    startDate = Self.defaultStartDate(now: now())
  }

  var canPublish: Bool {
    ImportCompleteness.isPublishable(weeks)
  }

  var selectedWeekCount: Int {
    weeks.filter(\.isSelected).count
  }

  /// Loads the catalog once (main lifts + variations + accessories) for matching.
  func loadCatalog() async {
    guard catalog.isEmpty else { return }
    do {
      async let mainLifts = repository.fetchMainLiftCatalog()
      async let accessories = repository.fetchAccessoryExercises(filters: .empty)
      let combined = try await mainLifts + accessories
      catalog = dedupe(combined)
    } catch {
      phase = .failed("动作库加载失败：\(error.localizedDescription)")
    }
  }

  /// Parses the chosen workbook locally and builds review state.
  func parse(fileURL: URL) async {
    phase = .parsing
    await loadCatalog()
    if case .failed = phase { return }
    do {
      let reader = XLSXReader(fileURL: fileURL)
      let grid = try Self.planGrid(from: reader)
      let parsed = PlanSheetParser.parse(grid)
      guard !parsed.weeks.isEmpty else {
        phase = .failed("没能在表里识别出训练周——请确认选择的是计划页。")
        return
      }
      weeks = ImportReviewBuilder.build(from: parsed, catalog: catalog)
      phase = .review
    } catch {
      phase = .failed("解析失败：\(error.localizedDescription)")
    }
  }

  func publish() async {
    guard canPublish else { return }
    phase = .publishing
    do {
      let assembled = try assembler.assemble(
        traineeID: student.id,
        coachID: nil,
        name: planName,
        startDate: startDate,
        weeks: weeks
      )
      try await repository.publishPlan(
        plan: assembled.plan,
        days: assembled.days,
        exercises: assembled.exercises,
        sets: assembled.sets
      )
      phase = .published
    } catch {
      phase = .failed("发布失败：\(error.localizedDescription)")
    }
  }

  // MARK: - review mutations

  func toggleWeek(_ weekID: ImportReviewWeek.ID) {
    guard let index = weeks.firstIndex(where: { $0.id == weekID }) else { return }
    weeks[index].isSelected.toggle()
  }

  func bind(exerciseID: UUID, isMainLift: Bool, to reviewExerciseID: ImportReviewExercise.ID) {
    mutateExercise(reviewExerciseID) { exercise in
      exercise.boundExerciseID = exerciseID
      exercise.isMainLift = isMainLift
    }
  }

  func candidates(for reviewExerciseID: ImportReviewExercise.ID) -> [Exercise] {
    guard let exercise = exercise(reviewExerciseID) else { return [] }
    return ExerciseMatcher.candidates(rawName: exercise.rawName, catalog: catalog)
  }

  func updateSet(
    _ setID: ImportReviewSet.ID,
    in reviewExerciseID: ImportReviewExercise.ID,
    transform: (inout ImportReviewSet) -> Void
  ) {
    mutateExercise(reviewExerciseID) { exercise in
      guard let index = exercise.sets.firstIndex(where: { $0.id == setID }) else { return }
      transform(&exercise.sets[index])
    }
  }

  // MARK: - lookups

  func exercise(_ id: ImportReviewExercise.ID) -> ImportReviewExercise? {
    for week in weeks {
      for day in week.days {
        if let match = day.exercises.first(where: { $0.id == id }) { return match }
      }
    }
    return nil
  }

  func boundExerciseName(_ id: UUID?) -> String? {
    guard let id else { return nil }
    return catalog.first { $0.id == id }?.name
  }

  // MARK: - helpers

  private func mutateExercise(
    _ id: ImportReviewExercise.ID,
    _ transform: (inout ImportReviewExercise) -> Void
  ) {
    for weekIndex in weeks.indices {
      for dayIndex in weeks[weekIndex].days.indices {
        if let exerciseIndex = weeks[weekIndex].days[dayIndex].exercises.firstIndex(where: {
          $0.id == id
        }) {
          transform(&weeks[weekIndex].days[dayIndex].exercises[exerciseIndex])
          return
        }
      }
    }
  }

  private func dedupe(_ exercises: [Exercise]) -> [Exercise] {
    var seen = Set<UUID>()
    return exercises.filter { seen.insert($0.id).inserted }
  }

  static func planGrid(from reader: XLSXReader) throws -> CellGrid {
    let names = (try? reader.sheetNames()) ?? []
    let planSheets = names.filter { !ignoredSheetNames.contains($0) }
    if planSheets.count == 1 {
      return try reader.cells(inSheetNamed: planSheets[0])
    }
    return try reader.firstSheetGrid()
  }

  nonisolated static func defaultStartDate(now: Date) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    let weekday = calendar.component(.weekday, from: now)  // 1 = Sun … 7 = Sat
    let daysUntilMonday = (9 - weekday) % 7
    let offset = daysUntilMonday == 0 ? 7 : daysUntilMonday  // always the *next* Monday
    return calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))
      ?? calendar.startOfDay(for: now)
  }
}
