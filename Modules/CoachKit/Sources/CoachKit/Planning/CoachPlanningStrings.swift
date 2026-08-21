// swiftlint:disable file_length
import Foundation

// swiftlint:disable:next type_body_length
enum CoachPlanningStrings {
  static let add = localized("coach.planning.common.add")
  static let cancel = localized("coach.planning.common.cancel")
  static let close = localized("coach.planning.common.close")
  static let delete = localized("coach.planning.common.delete")
  static let done = localized("coach.planning.common.done")
  static let edit = localized("coach.planning.common.edit")
  static let next = localized("coach.planning.common.next")
  static let retry = localized("coach.planning.common.retry")
  static let save = localized("coach.planning.common.save")
  static let all = localized("coach.planning.common.all")
  static let selected = localized("coach.planning.common.selected")
  static let mainLift = localized("coach.planning.common.mainLift")
  static let sets = localized("coach.planning.common.sets")
  static let reps = localized("coach.planning.common.reps")
  static let weight = localized("coach.planning.common.weight")
  static let unknownExercise = localized("coach.planning.common.unknownExercise")
  static let decrease = localized("coach.planning.common.decrease")
  static let increase = localized("coach.planning.common.increase")
  static let exerciseLibrary = localized("coach.planning.library.title")

  static let selectStudentPrompt = localized("coach.planning.step0.prompt")
  static let inEvaluation = localized("coach.planning.step0.inEvaluation")
  static let active = localized("coach.planning.step0.active")
  static let abnormal = localized("coach.planning.step0.abnormal")
  static let startPlanning = localized("coach.planning.step0.startPlanning")
  static let readyForPlan = localized("coach.planning.step0.readyForPlan")
  static let noStudents = localized("coach.roster.noStudents")
  static let noStudentsSubtitle = localized("coach.roster.noStudentsSubtitle")

  static let durationPrompt = localized("coach.planning.step1.prompt")
  static let durationTitle = localized("coach.planning.step1.navigationTitle")
  static let adaptationWeek = localized("coach.planning.step1.adaptationWeek")
  static let fullTrainingCycle = localized("coach.planning.step1.fullTrainingCycle")

  static let sbdFrequencyTitle = localized("coach.planning.step2.title")
  static let useTemplate = localized("coach.planning.step2.useTemplate")
  static let copyLastWeek = localized("coach.planning.step2.copyLastWeek")
  static let startFromScratch = localized("coach.planning.step2.startFromScratch")
  static let trainingDays = localized("coach.planning.step2.trainingDays")
  static let weeklyLiftFrequencyPrompt = localized("coach.planning.step2.frequencyPrompt")
  static let assignToTrainingDays = localized("coach.planning.step2.assignToDays")
  static let frequencyNavigationTitle = localized("coach.planning.step2.navigationTitle")

  static let selectMainLiftsTitle = localized("coach.planning.step3.title")
  static let chooseExercise = localized("coach.planning.step3.chooseExercise")
  static let search = localized("coach.planning.common.search")

  static let addAccessoriesTitle = localized("coach.planning.step4.title")
  static let addExercise = localized("coach.planning.step4.addExercise")
  static let completeAndConfigureRules = localized(
    "coach.planning.step4.completeAndConfigureRules"
  )
  static let finishTrainingDayAssignment = localized(
    "coach.planning.step4.finishTrainingDayAssignment"
  )
  static let almostThere = localized("coach.planning.step4.almostThere")
  static let acknowledge = localized("coach.planning.step4.acknowledge")
  static let todayMainLifts = localized("coach.planning.step4.todayMainLifts")
  static let todayMainLiftsSubtitle = localized("coach.planning.step4.todayMainLiftsSubtitle")

  static let clearSearch = localized("coach.planning.library.clearSearch")
  static let loadingExercises = localized("coach.planning.library.loadingExercises")
  static let noMatchingExercises = localized("coach.planning.library.noMatchingExercises")
  static let noSearchResults = localized("coach.planning.library.noSearchResults")
  static let filter = localized("coach.planning.library.filter")
  static let muscleGroup = localized("coach.planning.library.muscleGroup")
  static let equipment = localized("coach.planning.library.equipment")
  static let movementPattern = localized("coach.planning.library.movementPattern")

  static let intensityMode = localized("coach.planning.editor.intensityMode")
  static let notes = localized("coach.planning.editor.notes")
  static let notesPlaceholder = localized("coach.planning.editor.notesPlaceholder")
  static let filled = localized("coach.planning.editor.filled")
  static let addRepMaximum = localized("coach.planning.editor.addRepMaximum")
  static let repMaximum = localized("coach.planning.editor.repMaximum")
  static let removeRepMaximum = localized("coach.planning.editor.removeRepMaximum")
  static let restBetweenSets = localized("coach.planning.editor.restBetweenSets")
  static let setRestIndividually = localized("coach.planning.editor.setRestIndividually")
  static let rest = localized("coach.planning.editor.rest")

  static let weightUnit = localized("coach.planning.weight.unit")
  static let editWeight = localized("coach.planning.weight.editWeight")
  static let targetWeight = localized("coach.planning.weight.targetWeight")
  static let missingOneRM = localized("coach.planning.weight.missingOneRM")
  static let editCommonPercentages = localized("coach.planning.weight.editPercentages")
  static let commonPercentages = localized("coach.planning.weight.commonPercentages")
  static let newPercentage = localized("coach.planning.weight.newPercentage")
  static let restoreDefaults = localized("coach.planning.weight.restoreDefaults")
  static let value = localized("coach.planning.weight.value")
  static let openWeightPanel = localized("coach.planning.weight.openPanel")
  static let enterWeight = localized("coach.planning.weight.enter")

  static let progressionRulesTitle = localized("coach.planning.step6.title")
  static let emptyRules = localized("coach.planning.step6.emptyRules")
  static let addRule = localized("coach.planning.step6.addRule")
  static let completeRules = localized("coach.planning.step6.completeRules")
  static let uncoveredByRules = localized("coach.planning.step6.uncovered")
  static let listSeparator = localized("coach.planning.common.listSeparator")

  static let publishing = localized("coach.planning.step7.publishing")
  static let publishToStudent = localized("coach.planning.step7.publishToStudent")
  static let weekCards = localized("coach.planning.step7.weekCards")
  static let publishFailed = localized("coach.planning.step7.publishFailed")
  static let tryAgainLater = localized("coach.planning.step7.tryAgainLater")
  static let baseline = localized("coach.planning.weekCard.baseline")
  static let derived = localized("coach.planning.weekCard.derived")
  static let viewDetails = localized("coach.planning.weekCard.viewDetails")

  static let applyMainLiftVariations = localized(
    "coach.planning.rule.applyMainLiftVariations"
  )
  static let applyAccessories = localized("coach.planning.rule.applyAccessories")
  static let applyWeeks = localized("coach.planning.rule.applyWeeks")
  static let selectExerciseBeforeRule = localized("coach.planning.rule.selectExercise")
  static let overridden = localized("coach.planning.rule.overridden")
  static let ruleType = localized("coach.planning.rule.type")
  static let changeAmount = localized("coach.planning.rule.changeAmount")
  static let weeklyChange = localized("coach.planning.rule.weeklyChange")
  static let customDimension = localized("coach.planning.rule.customDimension")
  static let resetToWeekOne = localized("coach.planning.rule.resetToWeekOne")

  static let newPlan = localized("coach.planning.coordinator.newPlan")
  static let collapse = localized("coach.planning.studentHeader.collapse")
  static let expand = localized("coach.planning.studentHeader.expand")
  static let profileUnavailable = localized("coach.planning.studentHeader.profileUnavailable")
  static let basic = localized("coach.planning.studentHeader.basic")
  static let venue = localized("coach.planning.studentHeader.venue")
  static let injuries = localized("coach.planning.studentHeader.injuries")
  static let competition = localized("coach.planning.studentHeader.competition")
  static let note = localized("coach.planning.studentHeader.note")
  static let profile = localized("coach.planning.studentHeader.profile")
  static let profileNotCompleted = localized("coach.planning.studentHeader.profileNotCompleted")
  static let competitionPlanned = localized("coach.planning.profile.competitionPlanned")
  static let male = localized("coach.planning.profile.male")
  static let female = localized("coach.planning.profile.female")
  static let homeGymWithRack = localized("coach.planning.profile.homeGymWithRack")
  static let commercialGym = localized("coach.planning.profile.commercialGym")
  static let powerliftingGym = localized("coach.planning.profile.powerliftingGym")
  static let mondayShort = localized("coach.planning.profile.weekday.mon")
  static let tuesdayShort = localized("coach.planning.profile.weekday.tue")
  static let wednesdayShort = localized("coach.planning.profile.weekday.wed")
  static let thursdayShort = localized("coach.planning.profile.weekday.thu")
  static let fridayShort = localized("coach.planning.profile.weekday.fri")
  static let saturdayShort = localized("coach.planning.profile.weekday.sat")
  static let sundayShort = localized("coach.planning.profile.weekday.sun")
  static let shoulderInjury = localized("coach.planning.profile.injury.shoulder")
  static let elbowInjury = localized("coach.planning.profile.injury.elbow")
  static let wristInjury = localized("coach.planning.profile.injury.wrist")
  static let lowerBackInjury = localized("coach.planning.profile.injury.lowerBack")
  static let hipInjury = localized("coach.planning.profile.injury.hip")
  static let kneeInjury = localized("coach.planning.profile.injury.knee")
  static let ankleInjury = localized("coach.planning.profile.injury.ankle")
  static let missingPlanInformation = localized("coach.planning.publish.missingInformation")
  static let genericPublishFailed = localized("coach.planning.publish.genericFailure")

  static let squat = localized("coach.planning.lift.squat")
  static let benchPress = localized("coach.planning.lift.benchPress")
  static let deadlift = localized("coach.planning.lift.deadlift")

  static let chest = localized("coach.planning.muscle.chest")
  static let shoulder = localized("coach.planning.muscle.shoulder")
  static let back = localized("coach.planning.muscle.back")
  static let biceps = localized("coach.planning.muscle.biceps")
  static let triceps = localized("coach.planning.muscle.triceps")
  static let forearm = localized("coach.planning.muscle.forearm")
  static let core = localized("coach.planning.muscle.core")
  static let quadriceps = localized("coach.planning.muscle.quadriceps")
  static let hamstrings = localized("coach.planning.muscle.hamstrings")
  static let glutes = localized("coach.planning.muscle.glutes")
  static let hip = localized("coach.planning.muscle.hip")
  static let adductors = localized("coach.planning.muscle.adductors")
  static let calves = localized("coach.planning.muscle.calves")
  static let other = localized("coach.planning.common.other")

  static let barbell = localized("coach.planning.equipment.barbell")
  static let dumbbell = localized("coach.planning.equipment.dumbbell")
  static let machine = localized("coach.planning.equipment.machine")
  static let bodyweight = localized("coach.planning.equipment.bodyweight")
  static let cable = localized("coach.planning.equipment.cable")
  static let resistanceBand = localized("coach.planning.equipment.band")
  static let kettlebell = localized("coach.planning.equipment.kettlebell")
  static let specialtyBar = localized("coach.planning.equipment.specialtyBar")

  static let squatPattern = localized("coach.planning.pattern.squat")
  static let horizontalPush = localized("coach.planning.pattern.horizontalPush")
  static let verticalPush = localized("coach.planning.pattern.verticalPush")
  static let hipHinge = localized("coach.planning.pattern.hipHinge")
  static let horizontalPull = localized("coach.planning.pattern.horizontalPull")
  static let verticalPull = localized("coach.planning.pattern.verticalPull")
  static let warmUp = localized("coach.planning.pattern.warmUp")

  static let missingStudent = localized("coach.planning.validation.missingStudent")
  static let invalidDuration = localized("coach.planning.validation.invalidDuration")
  static let evaluationRequiresOneWeek = localized(
    "coach.planning.validation.evaluationRequiresOneWeek"
  )
  static let invalidFrequency = localized("coach.planning.validation.invalidFrequency")
  static let assignmentOutsideTrainingDays = localized(
    "coach.planning.validation.assignmentOutsideTrainingDays"
  )
  static let incompleteMainLiftVariants = localized(
    "coach.planning.validation.incompleteMainLiftVariants"
  )
  static let incompleteWeekOneSetSpecs = localized(
    "coach.planning.validation.incompleteWeekOneSetSpecs"
  )
  static let invalidWeekOneSetSpec = localized(
    "coach.planning.validation.invalidWeekOneSetSpec"
  )

  static let weightIncrease = localized("coach.planning.progression.weightIncrease")
  static let weightDecrease = localized("coach.planning.progression.weightDecrease")
  static let rpeIncrease = localized("coach.planning.progression.rpeIncrease")
  static let rpeDecrease = localized("coach.planning.progression.rpeDecrease")
  static let setIncrease = localized("coach.planning.progression.setIncrease")
  static let setDecrease = localized("coach.planning.progression.setDecrease")
  static let repIncrease = localized("coach.planning.progression.repIncrease")
  static let repDecrease = localized("coach.planning.progression.repDecrease")
  static let custom = localized("coach.planning.progression.custom")

  static let evaluationPublishBlocked = localized(
    "coach.planning.publish.evaluationBlocked"
  )
  static let planDaysExceedWeeks = localized("coach.planning.publish.daysExceedWeeks")

  static func daysNotTrained(_ days: Int) -> String {
    days == 1
      ? localized("coach.planning.abnormal.dayNotTrained \(days)")
      : localized("coach.planning.abnormal.daysNotTrained \(days)")
  }

  static func stuckOnWeek(_ week: Int) -> String {
    localized("coach.planning.abnormal.stuckOnWeek \(week)")
  }

  static func setCount(_ count: Int) -> String {
    count == 1
      ? localized("coach.planning.count.set \(count)")
      : localized("coach.planning.count.setPlural \(count)")
  }

  static func repCount(_ count: Int) -> String {
    count == 1
      ? localized("coach.planning.count.rep \(count)")
      : localized("coach.planning.count.repPlural \(count)")
  }

  static func setAndRepCount(sets: Int, reps: Int, multiplicationSign: String = "×") -> String {
    localized("coach.planning.count.setsAndReps \(sets) \(multiplicationSign) \(reps)")
  }

  static func evaluationRemaining(days: Int, hours: Int) -> String {
    localized("coach.planning.step0.evaluationRemaining \(days) \(hours)")
  }

  static func weekCount(_ count: Int) -> String {
    count == 1
      ? localized("coach.planning.count.week \(count)")
      : localized("coach.planning.count.weeks \(count)")
  }

  static func trainingDayCount(_ count: Int, fromProfile: Bool) -> String {
    switch (count == 1, fromProfile) {
    case (true, true): localized("coach.planning.step2.trainingDayFromProfile \(count)")
    case (false, true): localized("coach.planning.step2.trainingDaysFromProfile \(count)")
    case (true, false): localized("coach.planning.step2.trainingDayCount \(count)")
    case (false, false): localized("coach.planning.step2.trainingDaysCount \(count)")
    }
  }

  static func sessionsPerWeek(_ count: Int) -> String {
    count == 1
      ? localized("coach.planning.step2.sessionPerWeek \(count)")
      : localized("coach.planning.step2.sessionsPerWeek \(count)")
  }

  static func itemCount(_ count: Int) -> String {
    count == 1
      ? localized("coach.planning.count.item \(count)")
      : localized("coach.planning.count.items \(count)")
  }

  static func mainLiftVariationLabel(lift: String, selection: String) -> String {
    replacing(
      "coach.planning.step3.mainLiftVariationLabel",
      values: ["lift": lift, "selection": selection]
    )
  }

  static func mainLiftVariationTitle(_ lift: String) -> String {
    replacing("coach.planning.step3.mainLiftVariationTitle", values: ["lift": lift])
  }

  static func selectedExerciseCount(_ count: Int) -> String {
    count == 1
      ? localized("coach.planning.step4.selectedExercise \(count)")
      : localized("coach.planning.step4.selectedExercises \(count)")
  }

  static func completionIssues(_ issues: String) -> String {
    replacing("coach.planning.step4.completionIssues", values: ["issues": issues])
  }

  static func setRepIntensity(
    sets: Int,
    reps: String,
    singularReps: Bool,
    intensity: String
  ) -> String {
    switch (sets == 1, singularReps) {
    case (true, true):
      localized("coach.planning.step4.setRepIntensity \(sets) \(reps) \(intensity)")
    case (true, false):
      localized("coach.planning.step4.setRepsIntensity \(sets) \(reps) \(intensity)")
    case (false, true):
      localized("coach.planning.step4.setsRepIntensity \(sets) \(reps) \(intensity)")
    case (false, false):
      localized("coach.planning.step4.setsRepsIntensity \(sets) \(reps) \(intensity)")
    }
  }

  static func matchingExerciseCount(_ count: Int) -> String {
    count == 1
      ? localized("coach.planning.library.matchingExercise \(count)")
      : localized("coach.planning.library.matchingExercises \(count)")
  }

  static func addExerciseAccessibility(_ exerciseName: String) -> String {
    replacing("coach.planning.library.addExercise", values: ["exercise": exerciseName])
  }

  static func removeExerciseAccessibility(_ exerciseName: String) -> String {
    replacing("coach.planning.library.removeExercise", values: ["exercise": exerciseName])
  }

  static func deleteExerciseAccessibility(_ exerciseName: String) -> String {
    replacing("coach.planning.editor.deleteExercise", values: ["exercise": exerciseName])
  }

  static func setNumber(_ number: Int) -> String {
    localized("coach.planning.editor.setNumber \(number)")
  }

  static func removePercentage(_ percent: Int) -> String {
    localized("coach.planning.weight.removePercentage \(percent)")
  }

  static func currentWeight(_ weight: String) -> String {
    replacing("coach.planning.weight.currentWeight", values: ["weight": weight])
  }

  static func operation(_ operation: String) -> String {
    replacing("coach.planning.weight.operation", values: ["operation": operation])
  }

  static func uncoveredWeek(_ week: Int, exerciseNames: [String]) -> String {
    localized(
      "coach.planning.step6.uncoveredWeek \(week) \(exerciseNames.joined(separator: listSeparator))"
    )
  }

  static func publishCompletionIssues(_ issues: String) -> String {
    replacing("coach.planning.step7.completionIssues", values: ["issues": issues])
  }

  static func weekPosition(_ week: Int, total: Int) -> String {
    localized("coach.planning.weekCard.position \(week) \(total)")
  }

  static func baselineFooter() -> String {
    localized("coach.planning.weekCard.baselineFooter")
  }

  static func derivedFooter(_ week: Int) -> String {
    localized("coach.planning.weekCard.derivedFooter \(week)")
  }

  static func intensityWeight(_ weight: String) -> String {
    replacing("coach.planning.weekCard.intensityWeight", values: ["weight": weight])
  }

  static func intensityRPE(_ rpe: String) -> String {
    localized("coach.planning.weekCard.intensityRPE \(rpe)")
  }

  static func ruleNumber(_ number: Int) -> String {
    localized("coach.planning.rule.number \(number)")
  }

  static func weekValue(_ week: Int) -> String {
    localized("coach.planning.rule.weekValue \(week)")
  }

  static func oneRMSquat(_ value: String) -> String {
    replacing("coach.planning.profile.oneRMSquat", values: ["value": value])
  }

  static func oneRMBench(_ value: String) -> String {
    replacing("coach.planning.profile.oneRMBench", values: ["value": value])
  }

  static func oneRMDeadlift(_ value: String) -> String {
    replacing("coach.planning.profile.oneRMDeadlift", values: ["value": value])
  }

  static func weeklyTrainingDays(count: Int, names: String) -> String {
    count == 1
      ? localized("coach.planning.profile.weeklyTrainingDay \(count) \(names)")
      : localized("coach.planning.profile.weeklyTrainingDays \(count) \(names)")
  }

  static func extraEquipment(_ count: Int) -> String {
    count == 1
      ? localized("coach.planning.profile.extraEquipmentItem \(count)")
      : localized("coach.planning.profile.extraEquipmentItems \(count)")
  }

  static func missingMainLift(day: String) -> String {
    replacing("coach.planning.completion.missingMainLift", values: ["day": day])
  }

  static func missingIntensity(day: String, exercise: String) -> String {
    replacing(
      "coach.planning.completion.missingIntensity",
      values: ["day": day, "exercise": exercise]
    )
  }

  static func mainLiftBase(_ exercise: String) -> String {
    replacing("coach.planning.weight.mainLiftBase", values: ["exercise": exercise])
  }

  private static func localized(_ key: String.LocalizationValue) -> String {
    CoachLocalization.localized(key)
  }

  private static func replacing(
    _ key: String.LocalizationValue,
    values: [String: String]
  ) -> String {
    CoachLocalization.replacing(key, values: values)
  }
}
// swiftlint:enable file_length
