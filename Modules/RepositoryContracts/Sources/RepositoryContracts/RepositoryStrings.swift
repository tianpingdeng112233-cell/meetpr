import Foundation

enum RepositoryStrings {
  static let onlyLatestDayCanBeUndone = localized("repository.planDay.onlyLatestCanBeUndone")
  static let completionCanOnlyBeUndoneToday = localized("repository.planDay.undoTodayOnly")
  static let planIsNoLongerCurrent = localized("repository.planDay.notActive")
  static let dayCannotBeModified = localized("repository.planDay.notPlanStudent")
  static let operationUnavailable = localized("repository.planDay.unavailable")

  private static func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
  }
}
