// swiftlint:disable sorted_imports
import CoreModels
import Foundation
import OSLog
import Observation

// swiftlint:enable sorted_imports

// swiftlint:disable file_length type_body_length
@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
public final class PlanningViewModel {
  private static let logger = Logger(
    subsystem: "com.meetpr.app.coachkit",
    category: "planning"
  )

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
  public var selectedVariantNotes: [DayLiftKey: String] = [:]
  public var currentDayID: UUID?
  public var accessoryFiltersByDay: [UUID: AccessoryFilters] = [:]
  public var availableAccessoriesCache: [UUID: [Exercise]] = [:]
  public var isLoadingAccessories = false
  public private(set) var accessoryCatalogByID: [UUID: Exercise] = [:]
  public private(set) var draftPlan: DraftTrainingPlan?
  public var w1SetSpecs: [UUID: DraftSetSpec] = [:]
  public var lastIntensityModeMemo: [UUID: IntensityMode] = [:]
  public var progressionRules: [DraftProgressionRule] = []
  public var currentPreviewWeek = 1
  public var didFinish = false

  @ObservationIgnored private let repository: any PlanRepository
  @ObservationIgnored private let draftStore: DraftStore
  @ObservationIgnored private let usageTracker: ExerciseUsageTracker
  @ObservationIgnored private var hasBootstrapped = false
  @ObservationIgnored private var intensityValueMemo: [UUID: [IntensityMode: Decimal]] = [:]

  public init(
    repository: any PlanRepository,
    draftStore: DraftStore,
    usageTracker: ExerciseUsageTracker = ExerciseUsageTracker()
  ) {
    self.repository = repository
    self.draftStore = draftStore
    self.usageTracker = usageTracker
  }

  /// Variants for a lift family sorted by coach's usage frequency (DESC),
  /// tie-broken by localized name ASC. Frequently-picked variants float to top.
  public func sortedMainLiftVariants(for family: LiftFamily) -> [Exercise] {
    (mainLiftCatalog[family] ?? []).sorted { lhs, rhs in
      let lhsCount = usageTracker.usageCount(for: lhs.id)
      let rhsCount = usageTracker.usageCount(for: rhs.id)
      if lhsCount != rhsCount {
        return lhsCount > rhsCount
      }
      return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
  }

  /// Record a main lift variant pick so it surfaces higher next time the
  /// picker opens.
  public func recordVariantPick(_ exerciseID: UUID) {
    usageTracker.incrementUsage(for: exerciseID)
  }

  /// Pick (or change) a main lift variant for a day+family. Re-persists the
  /// draft so the DraftPlanExercise is materialized eagerly, which lets the
  /// Step 3 row inline an ExerciseSetEditorCard right after the pick.
  public func pickMainLiftVariant(_ exerciseID: UUID, for key: DayLiftKey) throws {
    recordVariantPick(exerciseID)
    selectedVariants[key] = exerciseID
    try persistDraft(currentStep: .selectMainLifts)
  }

  /// Returns the materialized DraftPlanExercise corresponding to a Step 3
  /// pick, or nil if the variant hasn't been picked yet for this day+family.
  public func mainLiftDraftExercise(for key: DayLiftKey) -> DraftPlanExercise? {
    guard let draftPlan else { return nil }
    return draftPlan.draftDays
      .first { $0.dayOfWeek == key.dayOfWeek }?
      .draftExercises
      .first { exercise in
        exercise.isMainLift
          && family(for: exercise.exerciseID) == key.liftFamily
      }
  }

  public var sortedTrainingDays: [Int] {
    [1, 2, 3, 4, 5, 6, 7]
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
      let accessories = try await repository.fetchAccessoryExercises(filters: .empty)
      accessoryCatalogByID = Dictionary(
        uniqueKeysWithValues: accessories.map { ($0.id, $0) }
      )
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
      try persistDraft(currentStep: .selectMainLifts)
      return
    case .selectMainLifts:
      path.append(.selectAccessories)
      try persistDraft(currentStep: .selectAccessories)
      if let dayID = currentDayID ?? sortedDraftDays.first?.id {
        await switchToDay(dayID)
      }
      return
    case .selectAccessories:
      try await proceedToStep6()
      return
    case .fillW1Intensity:
      try await proceedToStep6()
      return
    case .configureRules:
      try await proceedToStep7()
      return
    case .previewWeekCards:
      try await proceedToStep8()
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

  public func mainLiftExercises(for dayID: UUID) -> [DraftPlanExercise] {
    draftDay(with: dayID)?
      .draftExercises
      .filter(\.isMainLift)
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
  }

  public var sortedDraftExercises: [DraftPlanExercise] {
    sortedDraftDays.flatMap { day in
      sortedExercises(in: day)
    }
  }

  public func sortedExercises(in day: DraftPlanDay) -> [DraftPlanExercise] {
    day.draftExercises.sorted { lhs, rhs in
      if lhs.isMainLift == rhs.isMainLift {
        lhs.sortOrder < rhs.sortOrder
      } else {
        lhs.isMainLift && !rhs.isMainLift
      }
    }
  }

  public func catalogExercise(for draftExercise: DraftPlanExercise) -> Exercise? {
    if let exercise = mainLiftCatalog.values.flatMap({ $0 }).first(where: {
      $0.id == draftExercise.exerciseID
    }) {
      return exercise
    }
    return accessoryCatalogByID[draftExercise.exerciseID]
  }

  public func exerciseName(for draftExercise: DraftPlanExercise) -> String {
    catalogExercise(for: draftExercise)?.name ?? "未知动作"
  }

  public func exerciseNameEn(for draftExercise: DraftPlanExercise) -> String? {
    catalogExercise(for: draftExercise)?.nameEn
  }

  public func oneRM(for draftExercise: DraftPlanExercise) -> Decimal? {
    guard
      draftExercise.isMainLift,
      catalogExercise(for: draftExercise)?.mainLiftFamily != nil
    else {
      return nil
    }

    return nil
  }

  public func defaultSetSpec(for draftExercise: DraftPlanExercise) -> DraftSetSpec {
    DraftSetSpec(
      setCount: draftExercise.isMainLift ? 4 : 3,
      targetReps: draftExercise.isMainLift ? 5 : 10,
      intensityMode: lastIntensityModeMemo[draftExercise.id] ?? .weight,
      targetValue: intensityValueMemo[draftExercise.id]?[.weight] ?? Decimal(0)
    )
  }

  public func setSpec(for draftExerciseID: UUID) -> DraftSetSpec? {
    w1SetSpecs[draftExerciseID]
  }

  public func derivedSetSpec(
    forWeek week: Int,
    draftExercise: DraftPlanExercise
  ) -> DraftSetSpec? {
    guard let weekOne = w1SetSpecs[draftExercise.id] else { return nil }
    return WeekDerivation.deriveSetSpec(
      forWeek: week,
      exerciseID: draftExercise.id,
      w1: weekOne,
      rules: progressionRules
    )
  }

  public func updateW1SetSpec(
    _ spec: DraftSetSpec,
    for draftExerciseID: UUID
  ) async throws {
    guard let draftPlan, let exercise = draftExercise(with: draftExerciseID) else { return }
    let normalized = normalizedSetSpec(spec)

    w1SetSpecs[draftExerciseID] = normalized
    lastIntensityModeMemo[draftExerciseID] = normalized.intensityMode
    var memo = intensityValueMemo[draftExerciseID] ?? [:]
    memo[normalized.intensityMode] = normalized.targetValue
    intensityValueMemo[draftExerciseID] = memo

    exercise.setsData = try encodeSetSpec(normalized)
    draftPlan.currentStepRawValue = PlanningStep.fillW1Intensity.rawValue
    try draftStore.saveDraft(draftPlan)
  }

  public func updateExerciseNotes(
    _ notes: String?,
    for draftExerciseID: UUID
  ) async throws {
    guard let draftPlan, let exercise = draftExercise(with: draftExerciseID) else { return }
    let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
    exercise.notes = (trimmed?.isEmpty == false) ? trimmed : nil

    // Keep selectedVariantNotes dict in sync (for Step 3 binding consistency).
    if exercise.isMainLift {
      let key = dayLiftKey(for: exercise)
      if let key {
        if let updated = exercise.notes, !updated.isEmpty {
          selectedVariantNotes[key] = updated
        } else {
          selectedVariantNotes.removeValue(forKey: key)
        }
      }
    }

    try draftStore.saveDraft(draftPlan)
  }

  private func dayLiftKey(for exercise: DraftPlanExercise) -> DayLiftKey? {
    guard
      let day = exercise.day,
      let family = family(for: exercise.exerciseID)
    else { return nil }
    return DayLiftKey(dayOfWeek: day.dayOfWeek, liftFamily: family)
  }

  public func toggleIntensityMode(
    to newMode: IntensityMode,
    for draftExerciseID: UUID
  ) async {
    guard let draftExercise = draftExercise(with: draftExerciseID) else { return }
    var spec = w1SetSpecs[draftExerciseID] ?? defaultSetSpec(for: draftExercise)
    guard spec.intensityMode != newMode else { return }

    var memo = intensityValueMemo[draftExerciseID] ?? [:]
    memo[spec.intensityMode] = spec.targetValue
    spec.targetValue = memo[newMode] ?? defaultTargetValue(for: newMode)
    spec.intensityMode = newMode
    intensityValueMemo[draftExerciseID] = memo

    try? await updateW1SetSpec(spec, for: draftExerciseID)
  }

  /// Snapshot value used to seed custom-rule W2/W3/W4 inputs. Returns the
  /// median W1 value among the rule's applied exercises for the chosen
  /// dimension, or a sensible per-dimension default if nothing is set.
  public func w1Snapshot(
    for dimension: ProgressionRuleDimension,
    exerciseIDs: Set<UUID>
  ) -> Decimal {
    let specs = exerciseIDs.compactMap { setSpec(for: $0) }
    let values: [Decimal] = specs.compactMap { spec in
      switch dimension {
      case .weight:
        return spec.intensityMode == .weight ? spec.targetValue : nil
      case .rpe:
        return spec.intensityMode == .rpe ? spec.targetValue : nil
      case .sets:
        return Decimal(spec.setCount)
      case .reps:
        return Decimal(spec.targetReps)
      }
    }
    if values.isEmpty {
      switch dimension {
      case .weight: return 100
      case .rpe: return 8
      case .sets: return 4
      case .reps: return 8
      }
    }
    let sorted = values.sorted()
    return sorted[sorted.count / 2]
  }

  public func proceedToStep6() async throws {
    // Auto-fill defaults for any exercise the coach never opened — e.g. an
    // accessory on a day they added but didn't switch back to. Without this,
    // validateW1SetSpecs below would throw, the error is swallowed by try?
    // at the call site, and the proceed button would feel broken.
    for exercise in sortedDraftExercises where setSpec(for: exercise.id) == nil {
      let spec = defaultSetSpec(for: exercise)
      try await updateW1SetSpec(spec, for: exercise.id)
    }
    try validateStep(.fillW1Intensity)
    let nextStep: PlanningStep = planWeeks == 1 ? .previewWeekCards : .configureRules
    if let draftPlan {
      draftPlan.currentStepRawValue = nextStep.rawValue
      try draftStore.saveDraft(draftPlan)
    }
    path.append(nextStep)
  }

  public func makeDefaultProgressionRule() -> DraftProgressionRule {
    DraftProgressionRule(
      ruleType: .weightInc,
      incrementValue: Decimal(5),
      exerciseIDs: [],
      appliedWeeks: planWeeks == 1 ? [] : [2, 3],
      displayOrder: progressionRules.count
    )
  }

  public func addRule(_ rule: DraftProgressionRule) async throws {
    var nextRule = normalizedRule(rule)
    nextRule.displayOrder = (progressionRules.map(\.displayOrder).max() ?? -1) + 1
    progressionRules.append(nextRule)
    try persistRules(currentStep: .configureRules)
  }

  public func updateRule(_ rule: DraftProgressionRule) async throws {
    guard let index = progressionRules.firstIndex(where: { $0.id == rule.id }) else { return }
    progressionRules[index] = normalizedRule(rule)
    try persistRules(currentStep: .configureRules)
  }

  public func deleteRule(id: UUID) async throws {
    progressionRules.removeAll { $0.id == id }
    progressionRules =
      progressionRules
      .sorted { $0.displayOrder < $1.displayOrder }
      .enumerated()
      .map { offset, rule in
        var nextRule = rule
        nextRule.displayOrder = offset
        return nextRule
      }
    try persistRules(currentStep: .configureRules)
  }

  public func toggleAppliedWeek(_ week: Int, for ruleID: UUID) async throws {
    guard week != 1, (2...4).contains(week),
      let index = progressionRules.firstIndex(where: { $0.id == ruleID })
    else {
      return
    }

    var rule = progressionRules[index]
    if rule.appliedWeeks.contains(week) {
      rule.appliedWeeks.remove(week)
    } else {
      rule.appliedWeeks.insert(week)
    }
    progressionRules[index] = normalizedRule(rule)
    try persistRules(currentStep: .configureRules)
  }

  public func toggleRuleExercise(_ draftExerciseID: UUID, for ruleID: UUID) async throws {
    guard let index = progressionRules.firstIndex(where: { $0.id == ruleID }) else { return }

    var rule = progressionRules[index]
    if rule.exerciseIDs.contains(draftExerciseID) {
      // Tapping the active chip deselects it (rule applies to nothing).
      rule.exerciseIDs.removeAll()
    } else {
      // Single-select: a progression rule binds to exactly one exercise so
      // coaches can tune weight / RPE / increments per exercise. Picking a
      // new chip replaces the previous selection.
      rule.exerciseIDs = [draftExerciseID]
    }
    progressionRules[index] = normalizedRule(rule)
    try persistRules(currentStep: .configureRules)
  }

  public func uncoveredExercises(for week: Int) -> [DraftPlanExercise] {
    sortedDraftExercises.filter { exercise in
      !progressionRules.contains { rule in
        rule.appliedWeeks.contains(week) && rule.exerciseIDs.contains(exercise.id)
      }
    }
  }

  public func isRuleOverridden(_ rule: DraftProgressionRule) -> Bool {
    guard let dimension = rule.ruleType.dimension ?? rule.customDimension else { return false }
    return progressionRules.contains { otherRule in
      otherRule.id != rule.id
        && (otherRule.ruleType.dimension ?? otherRule.customDimension) == dimension
        && otherRule.displayOrder > rule.displayOrder
        && !otherRule.exerciseIDs.isDisjoint(with: rule.exerciseIDs)
        && !otherRule.appliedWeeks.isDisjoint(with: rule.appliedWeeks)
    }
  }

  public func proceedToStep7() async throws {
    try persistRules(currentStep: .previewWeekCards)
    path.append(.previewWeekCards)
  }

  public func setCurrentPreviewWeek(_ week: Int) {
    let upperBound = max(1, draftPlan?.planWeeks ?? planWeeks ?? 1)
    currentPreviewWeek = min(upperBound, max(1, week))
  }

  public func proceedToStep8() async throws {
    if let draftPlan {
      draftPlan.currentStepRawValue = PlanningStep.previewWeekCards.rawValue
      try draftStore.saveDraft(draftPlan)
    }
    Self.logger.warning("step8_pending")
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

  // swiftlint:disable:next cyclomatic_complexity
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
    case .fillW1Intensity:
      try validateStep(.selectAccessories)
      try validateW1SetSpecs()
    case .configureRules:
      try validateStep(.fillW1Intensity)
    case .previewWeekCards:
      try validateStep(.fillW1Intensity)
    }
  }

  private func validateW1SetSpecs() throws {
    let exerciseIDs = Set(sortedDraftExercises.map(\.id))
    guard !exerciseIDs.isEmpty, exerciseIDs.isSubset(of: Set(w1SetSpecs.keys)) else {
      throw PlanningValidationError.incompleteW1SetSpecs
    }

    let allSpecsAreValid = exerciseIDs.allSatisfy { exerciseID in
      guard let spec = w1SetSpecs[exerciseID] else { return false }
      return isValidSetSpec(spec)
    }
    guard allSpecsAreValid else {
      throw PlanningValidationError.invalidW1SetSpec
    }
  }

  private func isValidSetSpec(_ spec: DraftSetSpec) -> Bool {
    let hasValidRepsMax = spec.targetRepsMax.map { $0 >= spec.targetReps } ?? true
    let hasValidIntensity: Bool
    switch spec.intensityMode {
    case .weight:
      hasValidIntensity = spec.targetValue >= Decimal(0)
    case .rpe:
      hasValidIntensity = spec.targetValue >= Decimal(1) && spec.targetValue <= Decimal(10)
    }
    return spec.setCount >= 1
      && spec.targetReps >= 1
      && hasValidRepsMax
      && hasValidIntensity
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
        let existingExercise = draftDay.draftExercises.first { exercise in
          exercise.isMainLift && exercise.exerciseID == exerciseID
        }
        let draftExercise =
          existingExercise
          ?? DraftPlanExercise(
            exerciseID: exerciseID,
            isMainLift: true,
            sortOrder: pair.offset,
            day: draftDay
          )
        draftExercise.sortOrder = pair.offset
        draftExercise.day = draftDay
        let trimmedNote = selectedVariantNotes[key]?.trimmingCharacters(
          in: .whitespacesAndNewlines
        )
        draftExercise.notes = (trimmedNote?.isEmpty == false) ? trimmedNote : nil
        return draftExercise
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
    var notesByKey: [DayLiftKey: String] = [:]
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
        let key = DayLiftKey(dayOfWeek: day.dayOfWeek, liftFamily: family)
        variants[key] = exercise.exerciseID
        if let note = exercise.notes, !note.isEmpty {
          notesByKey[key] = note
        }
      }
    }

    dayAssignments = assignments
    selectedVariants = variants
    selectedVariantNotes = notesByKey
    sbdFrequency = frequency
    restoreStep7State(from: draft)

    if restoredStep == .selectAccessories {
      let sortedDays = draft.draftDays.sorted { $0.dayOfWeek < $1.dayOfWeek }
      let dayIDs = Set(sortedDays.map(\.id))
      let savedDayID = draftStore.loadCurrentDayID(traineeID: student.id)
      currentDayID = savedDayID.flatMap { dayIDs.contains($0) ? $0 : nil } ?? sortedDays.first?.id
    }
  }

  private func restoreStep7State(from draft: DraftTrainingPlan) {
    var restoredSpecs: [UUID: DraftSetSpec] = [:]
    var restoredModeMemo: [UUID: IntensityMode] = [:]
    var restoredValueMemo: [UUID: [IntensityMode: Decimal]] = [:]

    for exercise in draft.draftDays.flatMap(\.draftExercises) {
      guard let spec = decodeSetSpec(exercise.setsData) else { continue }
      restoredSpecs[exercise.id] = spec
      restoredModeMemo[exercise.id] = spec.intensityMode
      restoredValueMemo[exercise.id] = [spec.intensityMode: spec.targetValue]
    }

    w1SetSpecs = restoredSpecs
    lastIntensityModeMemo = restoredModeMemo
    intensityValueMemo = restoredValueMemo
    progressionRules = decodeRules(draft.progressionRulesData)
    currentPreviewWeek = 1
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
    case .fillW1Intensity:
      [.selectDuration, .assignFrequency, .selectMainLifts, .selectAccessories]
    case .configureRules:
      [
        .selectDuration,
        .assignFrequency,
        .selectMainLifts,
        .selectAccessories,
        .configureRules,
      ]
    case .previewWeekCards:
      if planWeeks == 4 {
        [
          .selectDuration,
          .assignFrequency,
          .selectMainLifts,
          .selectAccessories,
          .configureRules,
          .previewWeekCards,
        ]
      } else {
        [
          .selectDuration,
          .assignFrequency,
          .selectMainLifts,
          .selectAccessories,
          .previewWeekCards,
        ]
      }
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

  private func draftExercise(with draftExerciseID: UUID) -> DraftPlanExercise? {
    draftPlan?.draftDays
      .flatMap(\.draftExercises)
      .first { $0.id == draftExerciseID }
  }

  private func normalizedSetSpec(_ spec: DraftSetSpec) -> DraftSetSpec {
    var normalized = spec
    normalized.setCount = max(1, normalized.setCount)
    normalized.targetReps = max(1, normalized.targetReps)
    if let targetRepsMax = normalized.targetRepsMax {
      normalized.targetRepsMax = max(normalized.targetReps, targetRepsMax)
    }
    switch normalized.intensityMode {
    case .weight:
      normalized.targetValue = max(Decimal(0), normalized.targetValue)
        .roundedToPlanningIncrement(PlanningDecimalStep.half)
    case .rpe:
      normalized.targetValue = min(Decimal(10), max(Decimal(1), normalized.targetValue))
        .roundedToPlanningIncrement(PlanningDecimalStep.half)
    }
    return normalized
  }

  private func defaultTargetValue(for mode: IntensityMode) -> Decimal {
    switch mode {
    case .weight:
      Decimal(0)
    case .rpe:
      Decimal(7)
    }
  }

  private func normalizedRule(_ rule: DraftProgressionRule) -> DraftProgressionRule {
    var normalized = rule
    normalized.appliedWeeks = Set(normalized.appliedWeeks.filter { (2...4).contains($0) })

    if normalized.ruleType == .custom {
      normalized.incrementValue = nil
      if normalized.customDimension == nil {
        normalized.customDimension = .weight
      }
      let sortedWeeks = normalized.appliedWeeks.sorted()
      var sequence = normalized.customSequence ?? []
      if sequence.count < sortedWeeks.count {
        let fillValue = sequence.last ?? defaultCustomValue(for: normalized.customDimension)
        sequence += Array(repeating: fillValue, count: sortedWeeks.count - sequence.count)
      } else if sequence.count > sortedWeeks.count {
        sequence = Array(sequence.prefix(sortedWeeks.count))
      }
      sequence = sequence.map {
        $0.roundedToPlanningIncrement(step(for: normalized.customDimension))
      }
      normalized.customSequence = sequence
    } else {
      normalized.customDimension = nil
      normalized.customSequence = nil
      if normalized.incrementValue == nil {
        normalized.incrementValue = defaultIncrement(for: normalized.ruleType)
      }
      normalized.incrementValue = normalized.incrementValue?
        .roundedToPlanningIncrement(step(for: normalized.ruleType.dimension))
    }

    return normalized
  }

  private func defaultCustomValue(for dimension: ProgressionRuleDimension?) -> Decimal {
    switch dimension {
    case .weight:
      Decimal(100)
    case .rpe:
      Decimal(7)
    case .sets:
      Decimal(3)
    case .reps:
      Decimal(5)
    case nil:
      Decimal(0)
    }
  }

  private func defaultIncrement(for ruleType: ProgressionRuleType) -> Decimal {
    switch ruleType {
    case .weightInc, .weightDec:
      Decimal(5)
    case .rpeInc, .rpeDec:
      Decimal(string: "0.5") ?? Decimal(0)
    case .setsInc, .setsDec, .repsInc, .repsDec:
      Decimal(1)
    case .custom:
      Decimal(0)
    }
  }

  private func step(for dimension: ProgressionRuleDimension?) -> Decimal {
    switch dimension {
    case .sets, .reps:
      PlanningDecimalStep.whole
    case .weight, .rpe, nil:
      PlanningDecimalStep.half
    }
  }

  private func persistRules(currentStep: PlanningStep) throws {
    guard let draftPlan else { return }
    progressionRules =
      progressionRules
      .sorted { $0.displayOrder < $1.displayOrder }
      .enumerated()
      .map { offset, rule in
        var nextRule = normalizedRule(rule)
        nextRule.displayOrder = offset
        return nextRule
      }
    draftPlan.progressionRulesData = try encodeRules(progressionRules)
    draftPlan.currentStepRawValue = currentStep.rawValue
    try draftStore.saveDraft(draftPlan)
  }
}
// swiftlint:enable file_length type_body_length
