import CoreModels
import Foundation
import Observation

// swiftlint:disable file_length
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
  public var currentDayID: UUID?
  public var accessoryFiltersByDay: [UUID: AccessoryFilters] = [:]
  public var availableAccessoriesCache: [UUID: [Exercise]] = [:]
  public var isLoadingAccessories = false
  public private(set) var accessoryCatalogByID: [UUID: Exercise] = [:]
  public private(set) var draftPlan: DraftTrainingPlan?
  public var didFinish = false

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
      if currentStep == .selectAccessories, let currentDayID {
        await switchToDay(currentDayID)
      }
    } catch {
      availableStudents = []
      mainLiftCatalog = [:]
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
    let assignments = dayAssignments[dayOfWeek] ?? []
    return LiftFamily.allCases.filter { assignments.contains($0) }
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
      path.append(.selectAccessories)
      try persistDraft(currentStep: .selectAccessories)
      if let dayID = currentDayID ?? sortedDraftDays.first?.id {
        await switchToDay(dayID)
      }
      return
    case .selectAccessories:
      try await proceedToStep5()
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

  public var sortedDraftDays: [DraftPlanDay] {
    draftPlan?.draftDays.sorted { lhs, rhs in
      if lhs.dayOfWeek == rhs.dayOfWeek {
        lhs.sortOrder < rhs.sortOrder
      } else {
        lhs.dayOfWeek < rhs.dayOfWeek
      }
    } ?? []
  }

  public func accessoryFilters(for dayID: UUID) -> AccessoryFilters {
    accessoryFiltersByDay[dayID] ?? .empty
  }

  public func availableAccessories(for dayID: UUID) -> [Exercise] {
    availableAccessoriesCache[dayID] ?? []
  }

  public func selectedAccessories(for dayID: UUID) -> [DraftPlanExercise] {
    draftDay(with: dayID)?
      .draftExercises
      .filter { !$0.isMainLift }
      .sorted { $0.sortOrder < $1.sortOrder } ?? []
  }

  public func exerciseName(for exerciseID: UUID) -> String {
    accessoryCatalogByID[exerciseID]?.name ?? "未知动作"
  }

  public func accessoryExercise(for exerciseID: UUID) -> Exercise? {
    accessoryCatalogByID[exerciseID]
  }

  public func switchToDay(_ dayID: UUID) async {
    currentDayID = dayID
    if let traineeID = selectedStudent?.id {
      draftStore.saveCurrentDayID(dayID, traineeID: traineeID)
    }
    guard availableAccessoriesCache[dayID] == nil else { return }
    await reloadAccessoryExercises(for: dayID)
  }

  public func updateFilters(_ filters: AccessoryFilters, for dayID: UUID) async {
    accessoryFiltersByDay[dayID] = filters
    availableAccessoriesCache[dayID] = nil
    await reloadAccessoryExercises(for: dayID)
  }

  public func addAccessory(_ exercise: Exercise, to dayID: UUID) async throws {
    guard let draftPlan, let day = draftDay(with: dayID) else { return }
    accessoryCatalogByID[exercise.id] = exercise

    let nextSortOrder = (day.draftExercises.map(\.sortOrder).max() ?? -1) + 1
    let draftExercise = DraftPlanExercise(
      exerciseID: exercise.id,
      isMainLift: false,
      sortOrder: nextSortOrder,
      day: day
    )
    day.draftExercises.append(draftExercise)
    draftPlan.currentStepRawValue = PlanningStep.selectAccessories.rawValue
    try draftStore.saveDraft(draftPlan)
  }

  public func deleteAccessory(_ draftExerciseID: UUID, from dayID: UUID) async throws {
    guard let draftPlan, let day = draftDay(with: dayID) else { return }
    day.draftExercises.removeAll { exercise in
      exercise.id == draftExerciseID && !exercise.isMainLift
    }
    draftPlan.currentStepRawValue = PlanningStep.selectAccessories.rawValue
    try draftStore.saveDraft(draftPlan)
  }

  public func proceedToStep5() async throws {
    try validateStep(.selectAccessories)
    if let draftPlan {
      draftPlan.currentStepRawValue = PlanningStep.selectAccessories.rawValue
      try draftStore.saveDraft(draftPlan)
    } else {
      try persistDraft(currentStep: .selectAccessories)
    }
    print("step5_pending")
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
    case .selectAccessories:
      try validateStep(.selectMainLifts)
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
    let existingDaysByDayOfWeek = Dictionary(
      draft.draftDays.map { ($0.dayOfWeek, $0) },
      uniquingKeysWith: { first, _ in first }
    )

    return sortedAssignedDays.enumerated().map { index, dayOfWeek in
      let families = sortedLiftFamilies(in: dayOfWeek)
      let draftDay =
        existingDaysByDayOfWeek[dayOfWeek]
        ?? DraftPlanDay(dayOfWeek: dayOfWeek, sortOrder: index, plan: draft)

      draftDay.dayOfWeek = dayOfWeek
      draftDay.sortOrder = index
      draftDay.assignedLiftFamilyRawValues = families.map(\.rawValue)
      draftDay.plan = draft

      let mainLiftExercises: [DraftPlanExercise] = families.enumerated().compactMap { pair in
        let key = DayLiftKey(dayOfWeek: dayOfWeek, liftFamily: pair.element)
        guard let exerciseID = selectedVariants[key] else { return nil }
        return DraftPlanExercise(
          exerciseID: exerciseID,
          isMainLift: true,
          sortOrder: pair.offset,
          day: draftDay
        )
      }
      let accessoryExercises = draftDay.draftExercises
        .filter { !$0.isMainLift }
        .sorted { $0.sortOrder < $1.sortOrder }
      for exercise in accessoryExercises {
        exercise.day = draftDay
      }
      draftDay.draftExercises = mainLiftExercises + accessoryExercises

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

    if restoredStep == .selectAccessories {
      let sortedDays = draft.draftDays.sorted { $0.dayOfWeek < $1.dayOfWeek }
      let dayIDs = Set(sortedDays.map(\.id))
      let savedDayID = draftStore.loadCurrentDayID(traineeID: student.id)
      currentDayID = savedDayID.flatMap { dayIDs.contains($0) ? $0 : nil } ?? sortedDays.first?.id
    }
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
    case .selectAccessories:
      [.selectDuration, .assignFrequency, .selectMainLifts, .selectAccessories]
    }
  }

  private func reloadAccessoryExercises(for dayID: UUID) async {
    isLoadingAccessories = true
    defer { isLoadingAccessories = false }

    do {
      let exercises = try await repository.fetchAccessoryExercises(
        filters: accessoryFilters(for: dayID))
      availableAccessoriesCache[dayID] = exercises
      for exercise in exercises {
        accessoryCatalogByID[exercise.id] = exercise
      }
    } catch {
      availableAccessoriesCache[dayID] = []
    }
  }

  private func draftDay(with dayID: UUID) -> DraftPlanDay? {
    draftPlan?.draftDays.first { $0.id == dayID }
  }
}
// swiftlint:enable file_length
