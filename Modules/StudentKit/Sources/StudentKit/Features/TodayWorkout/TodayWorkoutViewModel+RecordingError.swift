import Networking

extension TodayWorkoutViewModel {
  static func recordingErrorMessage(for error: Error) -> String {
    if isAuthExpired(error) {
      return "登录已过期，请重新登录"
    }
    if BackendErrorEnvelope.machineCode(from: error) == "SETS_PLAN_EXERCISE_NOT_PUBLISHED" {
      return "训练计划已更新，请刷新训练页后重新记录。你的输入仍保留在本页。"
    }
    if case APIError.httpStatus(let statusCode, _) = error, statusCode >= 500 {
      return "服务器暂时无法保存（\(statusCode)），请稍后重试。你的输入仍保留在本页。"
    }
    return "记录没有保存，请重试。你的输入仍保留在本页。"
  }

  static func loadErrorMessage(for error: Error) -> String {
    isAuthExpired(error) ? "登录已过期，请重新登录" : "操作失败，请稍后重试"
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
