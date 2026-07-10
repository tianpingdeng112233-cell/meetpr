import Networking

extension TodayWorkoutViewModel {
  static func recordingErrorMessage(for error: Error) -> String {
    if BackendErrorEnvelope.machineCode(from: error) == "SETS_PLAN_EXERCISE_NOT_PUBLISHED" {
      return "训练计划已更新，请刷新训练页后重新记录。你的输入仍保留在本页。"
    }
    if case APIError.httpStatus(let statusCode, _) = error, statusCode >= 500 {
      return "服务器暂时无法保存（\(statusCode)），请稍后重试。你的输入仍保留在本页。"
    }
    return "记录没有保存，请重试。你的输入仍保留在本页。"
  }
}
