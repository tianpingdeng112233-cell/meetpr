import Foundation
import Testing

@testable import CoachKit

@Suite("Coach chat status subtitle")
struct CoachChatStatusSubtitleTests {
  @Test("unknown status shows no subtitle instead of claiming active")
  func unknownStatusStaysSilent() {
    let presentation = CoachChatStatusSubtitle.presentation(for: nil)

    // 这条是防回归的主戏:从今日页「待关注」待办进聊天时状态可能拿不到,
    // 若默认成 active,header 会显示绿色「活跃」——与该待办的存在前提相反。
    #expect(presentation.subtitle == nil)
  }

  @Test("abnormal students read as 待关注, not 活跃")
  func abnormalStatusReadsAsAttention() {
    let presentation = CoachChatStatusSubtitle.presentation(
      for: .abnormal(reason: .noTrainingForDays(3)))

    #expect(presentation.subtitle == CoachStrings.attentionStudentSubtitle)
    #expect(presentation.subtitle != CoachStrings.activeStudentSubtitle)
  }

  @Test("active and in-evaluation students read as 活跃")
  func activeStatusReadsAsActive() {
    #expect(
      CoachChatStatusSubtitle.presentation(for: .active).subtitle
        == CoachStrings.activeStudentSubtitle
    )
    #expect(
      CoachChatStatusSubtitle.presentation(for: .inEvaluation(remainingDays: 4, remainingHours: 12))
        .subtitle
        == CoachStrings.activeStudentSubtitle
    )
  }
}
