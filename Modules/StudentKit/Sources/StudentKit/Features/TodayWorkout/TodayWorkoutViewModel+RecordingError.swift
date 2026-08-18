import Networking

extension TodayWorkoutViewModel {
  static func recordingErrorMessage(for error: Error) -> String {
    if isAuthExpired(error) {
      return StudentStrings.localized(.todayWorkoutViewModelRecordingError001)
    }
    if BackendErrorEnvelope.machineCode(from: error) == "SETS_PLAN_EXERCISE_NOT_PUBLISHED" {
      return StudentStrings.localized(.todayWorkoutViewModelRecordingError002)
    }
    if case APIError.httpStatus(let statusCode, _) = error, statusCode >= 500 {
      return StudentStrings.replacing(
        .todayWorkoutViewModelRecordingError003, values: ["\(statusCode)"])
    }
    return StudentStrings.localized(.todayWorkoutViewModelRecordingError004)
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
