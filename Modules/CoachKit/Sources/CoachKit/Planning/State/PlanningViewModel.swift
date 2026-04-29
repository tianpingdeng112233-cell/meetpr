import CoreModels
import Foundation
import Observation

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
public final class PlanningViewModel {
  public var path: [PlanningStep] = []
  public var currentStep: PlanningStep {
    path.last ?? .selectStudent
  }

  public private(set) var availableStudents: [CoachStudentSummary] = []
  public var selectedStudent: CoachStudentSummary?
  public var planWeeks: Int?
  public var sbdFrequency: SBDFrequency = .empty
  public var dayAssignments: [Int: Set<LiftFamily>] = [:]
  public private(set) var mainLiftCatalog: [LiftFamily: [Exercise]] = [:]
  public var selectedVariants: [DayLiftKey: UUID] = [:]
  public private(set) var draftPlan: DraftTrainingPlan?
  public var didFinish = false
  public private(set) var errorMessage: String?

  @ObservationIgnored private let repository: any PlanRepository
  @ObservationIgnored private let draftStore: DraftStore
  @ObservationIgnored private var hasBootstrapped = false

  public init(repository: any PlanRepository, draftStore: DraftStore) {
    self.repository = repository
    self.draftStore = draftStore
  }

  public var sortedTrainingDays: [Int] {
    selectedStudent?.profile.trainingDaysOfWeek.sorted() ?? []
  }

  public var sortedAssignedDays: [Int] {
    dayAssignments.keys.sorted()
  }

  public var assignedLiftKeys: [DayLiftKey] {
    sortedAssignedDays.flatMap { day in
      sortedLiftFamilies(in: day).map { family in
        DayLiftKey(dayOfWeek: day, liftFamily: family)
      }
    }
  }

  public var isCurrentStepValid: Bool {
    do {
      try validateCurrentStep()
      return true
    } catch {
      return false
    }
  }

  public func bootstrap() async {
    guard !hasBootstrapped else { return }
    hasBootstrapped = true

    do {
      availableStudents = try await repository.fetchStudents()
      let catalog = try await repository.fetchMainLiftCatalog()
      mainLiftCatalog = Dictionary(
        grouping: catalog.compactMap { exercise -> Exercise? in
          exercise.mainLiftFamily == nil ? nil : exercise
        }
      ) { exercise in
        exercise.mainLiftFamily ?? .squat
      }
      try resumeMostRecentDraft()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func selectStudent(_ student: CoachStudentSummary) {
    selectedStudent = student
    if isEvaluationStudent, planWeeks == 4 {
      planWeeks = 1
    }
  }

  public func selectDuration(_ weeks: Int) {
    planWeeks = weeks
  }

  public func toggleAssignment(dayOfWeek: Int, liftFamily: LiftFamily) {
    var assignments = dayAssignments[dayOfWeek] ?? []
    if assignments.contains(liftFamily) {
      assignments.remove(liftFamily)
      selectedVariants[DayLiftKey(dayOfWeek: dayOfWeek, liftFamily: liftFamily)] = nil
    } else {
      assignments.insert(liftFamily)
    }

    if assignments.isEmpty {
      dayAssignments[dayOfWeek] = nil
    } else {
      dayAssignments[dayOfWeek] = assignments
    }
  }

  public func sortedLiftFamilies(in dayOfWeek: Int) -> [LiftFamily] {
    let order: [LiftFamily] = [.squat, .bench, .deadlift]
    let assignments = dayAssignments[dayOfWeek] ?? []
    return order.filter { assignments.contains($0) }
  }

  public func assignedCount(for dayOfWeek: Int) -> Int {
    dayAssignments[dayOfWeek]?.count ?? 0
  }

  public func goNext() async throws {
    try validateCurrentStep()

    switch currentStep {
    case .selectStudent:
      path.append(.selectDuration)
    case .selectDuration:
      path.append(.assignFrequency)
    case .assignFrequency:
      path.append(.selectMainLifts)
    case .selectMainLifts:
      try await finish()
      return
    }

    try persistDraft(currentStep: currentStep)
  }

  public func goBack() {
    guard !path.isEmpty else { return }
    path.removeLast()
  }

  public func finish() async throws {
    try validateStep(.selectMainLifts)
    try persistDraft(currentStep: .selectMainLifts)
    didFinish = true
  }

  public func validateCurrentStep() throws {
    try validateStep(currentStep)
  }
}

@available(iOS 17.0, macOS 14.0, *)
extension PlanningViewModel {
  private var isEvaluationStudent: Bool {
    guard let selectedStudent else { return false }
    if case .inEvaluation = selectedStudent.status {
      return true
    }
    return false
  }

  private func validateStep(_ step: PlanningStep) throws {
    switch step {
    case .selectStudent:
      guard selectedStudent != nil else {
        throw PlanningValidationError.missingStudent
      }
    case .selectDuration:
      guard let planWeeks, [1, 4].contains(planWeeks) else {
        throw PlanningValidationError.invalidDuration
      }
      if isEvaluationStudent, planWeeks != 1 {
        throw PlanningValidationError.evaluationStudentRequiresOneWeek
      }
    case .assignFrequency:
      try validateAssignments()
    case .selectMainLifts:
      try validateAssignments()
      let allVariantsSelected = assignedLiftKeys.allSatisfy { key in
        selectedVariants[key] != nil
      }
      guard allVariantsSelected else {
        throw PlanningValidationError.incompleteMainLiftVariants
      }
    }
  }

  private func validateAssignments() throws {
    let trainingDays = Set(sortedTrainingDays)
    let assignedDays = Set(dayAssignments.keys)
    guard assignedDays.isSubset(of: trainingDays) else {
      throw PlanningValidationError.assignmentOutsideTrainingDays
    }

    let assignmentCount = dayAssignments.values.reduce(0) { $0 + $1.count }
    guard sbdFrequency.isWithinRange,
      sbdFrequency.totalSessions > 0,
      sbdFrequency.totalSessions == assignmentCount
    else {
      throw PlanningValidationError.invalidFrequency
    }
  }

  private func persistDraft(currentStep: PlanningStep) throws {
    guard let selectedStudent, let planWeeks else { return }

    let startDate = Calendar.current.startOfDay(for: Date())
    let endDate =
      Calendar.current.date(
        byAdding: .day,
        value: (planWeeks * 7) - 1,
        to: startDate
      ) ?? startDate

    let draft =
      draftPlan
      ?? DraftTrainingPlan(
        traineeID: selectedStudent.id,
        name: "\(selectedStudent.displayName) \(planWeeks) 周计划",
        startDate: startDate,
        endDate: endDate,
        planWeeks: planWeeks,
        currentStepRawValue: currentStep.rawValue
      )

    draft.traineeID = selectedStudent.id
    draft.name = "\(selectedStudent.displayName) \(planWeeks) 周计划"
    draft.startDate = startDate
    draft.endDate = endDate
    draft.planWeeks = planWeeks
    draft.currentStepRawValue = currentStep.rawValue
    draft.draftDays = makeDraftDays(for: draft)

    try draftStore.saveDraft(draft)
    draftPlan = draft
  }

  private func makeDraftDays(for draft: DraftTrainingPlan) -> [DraftPlanDay] {
    sortedAssignedDays.enumerated().map { index, dayOfWeek in
      let families = sortedLiftFamilies(in: dayOfWeek)
      let draftDay = DraftPlanDay(
        dayOfWeek: dayOfWeek,
        sortOrder: index,
        assignedLiftFamilyRawValues: families.map(\.rawValue),
        plan: draft
      )

      draftDay.draftExercises = families.enumerated().compactMap { exerciseIndex, family in
        let key = DayLiftKey(dayOfWeek: dayOfWeek, liftFamily: family)
        guard let exerciseID = selectedVariants[key] else { return nil }
        return DraftPlanExercise(
          exerciseID: exerciseID,
          isMainLift: true,
          sortOrder: exerciseIndex,
          day: draftDay
        )
      }

      return draftDay
    }
  }

  private func resumeMostRecentDraft() throws {
    for student in availableStudents {
      if let draft = try draftStore.loadDraft(traineeID: student.id) {
        restore(draft: draft, student: student)
        return
      }
    }
  }

  private func restore(draft: DraftTrainingPlan, student: CoachStudentSummary) {
    draftPlan = draft
    selectedStudent = student
    planWeeks = draft.planWeeks

    let restoredStep = PlanningStep(rawValue: draft.currentStepRawValue) ?? .selectStudent
    path = pathForRestoredStep(restoredStep)

    var assignments: [Int: Set<LiftFamily>] = [:]
    var variants: [DayLiftKey: UUID] = [:]
    var frequency = SBDFrequency.empty

    for day in draft.draftDays {
      let families = restoreFamilies(from: day)
      if !families.isEmpty {
        assignments[day.dayOfWeek] = families
      }

      for family in families {
        switch family {
        case .squat:
          frequency.squat += 1
        case .bench:
          frequency.bench += 1
        case .deadlift:
          frequency.deadlift += 1
        }
      }

      for exercise in day.draftExercises {
        guard let family = family(for: exercise.exerciseID) else { continue }
        variants[DayLiftKey(dayOfWeek: day.dayOfWeek, liftFamily: family)] = exercise.exerciseID
      }
    }

    dayAssignments = assignments
    selectedVariants = variants
    sbdFrequency = frequency
  }

  private func restoreFamilies(from day: DraftPlanDay) -> Set<LiftFamily> {
    let rawFamilies = day.assignedLiftFamilyRawValues.compactMap(LiftFamily.init(rawValue:))
    if !rawFamilies.isEmpty {
      return Set(rawFamilies)
    }

    let families = day.draftExercises.compactMap { exercise in
      family(for: exercise.exerciseID)
    }
    return Set(families)
  }

  private func family(for exerciseID: UUID) -> LiftFamily? {
    mainLiftCatalog.values
      .flatMap { $0 }
      .first { $0.id == exerciseID }?
      .mainLiftFamily
  }

  private func pathForRestoredStep(_ step: PlanningStep) -> [PlanningStep] {
    switch step {
    case .selectStudent:
      []
    case .selectDuration:
      [.selectDuration]
    case .assignFrequency:
      [.selectDuration, .assignFrequency]
    case .selectMainLifts:
      [.selectDuration, .assignFrequency, .selectMainLifts]
    }
  }
}
