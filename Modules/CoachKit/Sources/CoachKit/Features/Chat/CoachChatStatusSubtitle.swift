import DesignSystem
import SwiftUI

/// 聊天 header 副标题「● 学员 · 活跃 / 待关注」的取值(样机 743 行)。
///
/// 抽成纯函数是为了让「状态未知不许编造」这条有测试兜着:副标题曾经把 `nil` 状态
/// 默认成绿色「活跃」,于是「今日页待关注待办 → 聊天」显示成活跃——而那条待办的
/// 存在前提恰恰是该学员多日未训练,界面等于说谎(review-loop 2026-07-30 逮到)。
enum CoachChatStatusSubtitle {
  static func presentation(
    for status: CoachStudentStatus?
  ) -> (subtitle: String?, color: Color) {
    switch status {
    case .abnormal:
      (CoachStrings.attentionStudentSubtitle, Color.MeetPR.danger)
    case .active, .inEvaluation:
      (CoachStrings.activeStudentSubtitle, Color.MeetPR.success)
    case .none:
      // 拿不到状态就只显示姓名。副标题是 String?,传 nil 即整行不渲染——
      // 这是此处唯一诚实的落法,别拿任一档当默认。
      (nil, Color.MeetPR.textTertiary)
    }
  }
}
