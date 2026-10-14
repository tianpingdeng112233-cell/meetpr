import Networking

extension TodayWorkoutViewModel {
  static func recordingErrorMessage(for error: Error) -> String {
    if isAuthExpired(error) {
      return StudentStrings.localized(.todayWorkoutViewModelRecordingError001)
    }
    let code = BackendErrorEnvelope.machineCode(from: error)
    if let message = addedErrorMessage(error, code: code) { return message }
    if code == "SETS_PLAN_EXERCISE_NOT_PUBLISHED" || code == "SETS_PLAN_DAY_NOT_PUBLISHED" {
      return StudentStrings.localized(.todayWorkoutViewModelRecordingError002)
    }
    if case APIError.httpStatus(let statusCode, _) = error, statusCode >= 500 {
      return StudentStrings.replacing(
        .todayWorkoutViewModelRecordingError003, values: ["\(statusCode)"])
    }
    return StudentStrings.localized(.todayWorkoutViewModelRecordingError004)
  }

  private static func addedErrorMessage(_ error: Error, code: String?) -> String? {
    switch code {
    case "SET_HAS_ATTACHMENT": return StudentStrings.localized(.addedHasVideo)
    case "SET_HAS_COACH_FEEDBACK": return StudentStrings.localized(.addedRated)
    case "SETS_ADHOC_DAY_CONFLICT": return StudentStrings.localized(.addedDayConflict)
    case "SET_NOT_STUDENT_ADDED": return StudentStrings.localized(.addedNotAdded)
    default: break
    }
    if let addedError = error as? StudentAddedLogError {
      switch addedError {
      case .dayConflict: return StudentStrings.localized(.addedDayConflict)
      case .coachFeedback: return StudentStrings.localized(.addedRated)
      case .unavailable: break
      }
    }
    return nil
  }

  static func loadErrorMessage(for error: Error) -> String {
    isAuthExpired(error)
      ? StudentStrings.localized(.todayWorkoutViewModelRecordingError001)
      : StudentStrings.localized(.todayWorkoutViewModelRecordingError005)
  }

  /// Session-state errors and an unrecovered 401 both mean the stored
  /// credentials are dead; the only useful next action is signing in again.
  private static func isAuthExpired(_ error: Error) -> Bool {
    switch error {
    case is SessionStateReaderError, APIError.authInvalid:
      return true
    default:
      return false
    }
  }
}
