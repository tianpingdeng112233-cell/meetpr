import Foundation

public enum DesignSystemStrings {
  public static let startTraining = localized("designSystem.action.startTraining")
  public static let squatBenchDeadlift = localized("designSystem.action.squatBenchDeadlift")

  static let cancel = localized("designSystem.action.cancel")
  static let confirm = localized("designSystem.action.confirm")
  static let shiftOneDay = localized("designSystem.action.shiftOneDay")
  static let signOut = localized("designSystem.action.signOut")
  static let actionInProgress = localized("designSystem.action.inProgress")
  static let performAction = localized("designSystem.action.perform")
  static let appearanceSystem = localized("designSystem.appearance.system")
  static let appearanceLight = localized("designSystem.appearance.light")
  static let appearanceDark = localized("designSystem.appearance.dark")
  static let enterReps = localized("designSystem.numberPad.enterReps")
  static let enterWeight = localized("designSystem.numberPad.enterWeight")
  static let weight = localized("designSystem.weight")
  static let reps = localized("designSystem.reps")
  static let repsUnit = localized("designSystem.repsUnit")
  static let decimalPoint = localized("designSystem.numberPad.decimalPoint")
  static let backspace = localized("designSystem.numberPad.backspace")
  static let emptyBar = localized("designSystem.plate.emptyBar")
  static let competitionCollarsOnly = localized("designSystem.plate.competitionCollarsOnly")
  static let tapToEditSet = localized("designSystem.setRow.tapToEdit")
  static let setPending = localized("designSystem.setRow.pending")
  static let setDone = localized("designSystem.setRow.done")
  static let setFailed = localized("designSystem.setRow.failed")
  static let noVideo = localized("designSystem.video.none")
  static let videoAttached = localized("designSystem.video.attached")
  static let videoUploadFailed = localized("designSystem.video.uploadFailed")
  static let videoUploadFailedRetry = localized("designSystem.video.uploadFailedRetry")
  static let noSuggestedWeight = localized("designSystem.setRow.noSuggestedWeight")
  static let expanded = localized("designSystem.expanded")
  static let collapsed = localized("designSystem.collapsed")
  static let importedHistoryLegend = localized("designSystem.e1rm.importedHistoryLegend")
  static let date = localized("designSystem.chart.date")
  static let segment = localized("designSystem.chart.segment")
  static let trainingVolume = localized("designSystem.chart.trainingVolume")
  static let averageRPE = localized("designSystem.chart.averageRPE")
  static let trainingVolumeKilograms = localized("designSystem.chart.trainingVolumeKilograms")
  static let current = localized("designSystem.preview.current")
  static let coachNotified = localized("designSystem.preview.coachNotified")
  static let threeDaysWithoutTraining = localized("designSystem.preview.threeDaysWithoutTraining")
  static let restDay = localized("designSystem.day.rest")
  static let completed = localized("designSystem.day.completed")
  static let plannedButIncomplete = localized("designSystem.day.plannedButIncomplete")
  static let today = localized("designSystem.day.today")
  static let future = localized("designSystem.day.future")
  static let weekdayMonday = localized("designSystem.weekday.monday")
  static let weekdayTuesday = localized("designSystem.weekday.tuesday")
  static let weekdayWednesday = localized("designSystem.weekday.wednesday")
  static let weekdayThursday = localized("designSystem.weekday.thursday")
  static let weekdayFriday = localized("designSystem.weekday.friday")
  static let bodyWeight = localized("designSystem.preview.bodyWeight")
  static let daysUntilMeet = localized("designSystem.preview.daysUntilMeet")
  static let streak = localized("designSystem.preview.streak")
  static let missedWorkout = localized("designSystem.preview.missedWorkout")
  static let daysUnit = localized("designSystem.preview.daysUnit")
  static let timesUnit = localized("designSystem.preview.timesUnit")
  static let deadlift = localized("designSystem.preview.deadlift")
  static let tempoBench = localized("designSystem.preview.tempoBench")
  static let previousBestDeadlift = localized("designSystem.preview.previousBestDeadlift")
  static let previousBestTempoBench = localized("designSystem.preview.previousBestTempoBench")
  static let deadliftNote = localized("designSystem.preview.deadliftNote")
  static let todayTitle = localized("designSystem.preview.todayTitle")
  static let mesocycleWeek = localized("designSystem.preview.mesocycleWeek")
  static let strengthBlock = localized("designSystem.preview.strengthBlock")
  static let coachTopSetBackOff = localized("designSystem.preview.coachTopSetBackOff")
  static let previewInitials = localized("designSystem.preview.initials")
}

extension DesignSystemStrings {
  static func plateWithCollars(_ base: String) -> String {
    String(localized: "designSystem.plate.withCollars \(base)", bundle: .module)
  }

  static func recordedSets(_ completed: Int, total: Int) -> String {
    let formattedCompleted = String(completed)
    let formattedTotal = String(total)
    return String(
      localized: "designSystem.exercise.recordedSets \(formattedCompleted) of \(formattedTotal)",
      bundle: .module
    )
  }

  static func incompleteSets(_ count: Int) -> String {
    let formattedCount = String(count)
    if count == 1 {
      return String(
        localized: "designSystem.exercise.incompleteSet \(formattedCount)",
        bundle: .module
      )
    }
    return String(
      localized: "designSystem.exercise.incompleteSets \(formattedCount)",
      bundle: .module
    )
  }

  static func exerciseSummary(
    completed: Int,
    prescription: String,
    failure: String
  ) -> String {
    let formattedCompleted = String(completed)
    if completed == 1 {
      return String(
        localized:
          "designSystem.exercise.summaryOne \(formattedCompleted) \(prescription) \(failure)",
        bundle: .module
      )
    }
    return String(
      localized:
        "designSystem.exercise.summary \(formattedCompleted) \(prescription) \(failure)",
      bundle: .module
    )
  }

  static func e1rmChartLabel(_ count: Int) -> String {
    let formattedCount = String(count)
    if count == 1 {
      return String(
        localized: "designSystem.e1rm.chartLabelOne \(formattedCount)",
        bundle: .module
      )
    }
    return String(
      localized: "designSystem.e1rm.chartLabel \(formattedCount)",
      bundle: .module
    )
  }

  static func monthDay(month: Int, day: Int) -> String {
    let formattedMonth = String(month)
    let formattedDay = String(day)
    return String(
      localized: "designSystem.date.monthDay \(formattedMonth) \(formattedDay)",
      bundle: .module
    )
  }

  static func weeklyProgress(_ percent: Int) -> String {
    let formattedPercent = String(percent)
    return String(
      localized: "designSystem.progress.weekly \(formattedPercent)",
      bundle: .module
    )
  }

  static func dayAccessibilityLabel(weekday: String, date: Int, state: String) -> String {
    let formattedDate = String(date)
    return String(
      localized: "designSystem.day.accessibilityLabel \(weekday) \(formattedDate) \(state)",
      bundle: .module
    )
  }

  static func setWeight(_ weight: String) -> String {
    String(localized: "designSystem.setRow.weight \(weight)", bundle: .module)
  }

  static func setMetrics(weight: String, reps: Int, rpe: String) -> String {
    let formattedReps = String(reps)
    return String(
      localized: "designSystem.setRow.metrics \(weight) \(formattedReps) \(rpe)",
      bundle: .module
    )
  }

  static func setAccessibilityLabel(
    index: Int,
    metrics: String,
    status: String,
    video: String
  ) -> String {
    let formattedIndex = String(index)
    return String(
      localized:
        "designSystem.setRow.accessibilityLabel \(formattedIndex) \(metrics) \(status) \(video)",
      bundle: .module
    )
  }

  static func statAccessibilityLabel(
    label: String,
    value: String,
    unit: String,
    delta: String
  ) -> String {
    String(
      localized: "designSystem.stat.accessibilityLabel \(label) \(value) \(unit) \(delta)",
      bundle: .module
    )
  }

  static func statChange(_ delta: String) -> String {
    String(localized: "designSystem.stat.change \(delta)", bundle: .module)
  }
}

extension DesignSystemStrings {
  private static func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
  }
}
