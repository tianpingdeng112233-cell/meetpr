import CoreModels
import DesignSystem
import Foundation

enum DashboardFeedbackText {
  static func label(for item: CoachFeedback) -> String {
    guard let video = item.video else { return "训练反馈" }
    let exercise = video.exerciseName ?? "训练视频"
    guard let setIndex = video.setIndex else { return exercise }
    // spec 029 C0: set_logs.set_index stays zero-based until the display layer.
    let setNumber = SetIndexDisplay.number(forZeroBasedIndex: setIndex)
    return "\(exercise) · 第 \(setNumber) 组"
  }

  static func weekday(for item: CoachFeedback) -> String {
    let date = item.dayDate ?? item.postedAt
    let weekday = Calendar.current.component(.weekday, from: date)
    let offset = (weekday + 5) % 7
    return "周\(DashboardTodayPresentation.weekdayLetter(offset))"
  }
}
