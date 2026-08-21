import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite("StudentKit localization")
struct StudentStringsTests {
  private let chinese = Locale(identifier: "zh-Hans")
  private let english = Locale(identifier: "en")

  @Test("Critical Chinese copy remains byte-identical")
  func criticalChineseCopy() {
    #expect(
      StudentStrings.localized(.bindEnterCodeSubviews001, locale: chinese)
        == "输入教练邀请码"
    )
    #expect(
      StudentStrings.localized(.todayWorkoutScreen017, locale: chinese)
        == "今日训练"
    )
    #expect(
      StudentStrings.localized(.readinessCheckinSheet006, locale: chinese)
        == "今天状态如何？"
    )
    #expect(
      StudentStrings.localized(.trainingHistoryView024, locale: chinese)
        == "训练历史"
    )
    #expect(
      StudentStrings.localized(.cameraRecorderView013, locale: chinese)
        == "保存到相册失败，视频仍会继续上传"
    )
  }

  @Test("Dynamic Chinese templates preserve the original result")
  func dynamicChineseCopy() {
    #expect(
      StudentStrings.replacing(
        .dayCompletionBanner001,
        values: ["3"],
        locale: chinese
      ) == "今日训练完成 · 3 组"
    )
    #expect(
      StudentStrings.replacing(
        .evaluationPeriodViewModel001,
        values: ["4", "13"],
        locale: chinese
      ) == "评估期还剩: 4 天 13 小时"
    )
    #expect(
      StudentStrings.replacing(
        .todayWorkoutTypes011,
        values: ["200"],
        locale: chinese
      ) == "按登记 1RM 200 kg 换算 · 改动后按你填的为准"
    )
    #expect(
      StudentStrings.replacing(
        .todayWorkoutTypes012,
        values: ["196"],
        locale: chinese
      ) == "按当前 e1RM 196 kg 换算 · 改动后按你填的为准"
    )
    #expect(
      StudentStrings.replacing(
        .todayWorkoutTypes013,
        values: ["150"],
        locale: chinese
      ) == "按当日顶组 150 kg 换算 · 改动后按你填的为准"
    )
    #expect(
      StudentStrings.localized(.todayWorkoutTypes010, locale: chinese)
        == "先完成顶组，退让组会自动算好"
    )
  }

  @Test("Critical English copy is available")
  func criticalEnglishCopy() {
    #expect(
      StudentStrings.localized(.bindEnterCodeSubviews001, locale: english)
        == "Enter coach invite code"
    )
    #expect(
      StudentStrings.localized(.todayWorkoutScreen017, locale: english)
        == "Today's workout"
    )
    #expect(
      StudentStrings.localized(.readinessCheckinSheet006, locale: english)
        == "How do you feel today?"
    )
    #expect(
      StudentStrings.localized(.trainingHistoryView024, locale: english)
        == "Training history"
    )
    #expect(
      StudentStrings.replacing(
        .dayDetailView001,
        values: ["2"],
        locale: english
      ) == "Set 2"
    )
    #expect(
      StudentStrings.replacing(
        .todayWorkoutTypes013,
        values: ["200"],
        locale: english
      ) == "Calculated from today's top set 200 kg · Your entry overrides this"
    )
    #expect(
      StudentStrings.localized(.todayWorkoutTypes008, locale: english)
        == "Coach prescribed a percentage, but this exercise has no reference 1RM"
    )
  }

  @Test("List punctuation follows locale without changing Chinese output")
  func localizedListPunctuation() {
    let values = ["深蹲", "卧推"]
    #expect(StudentStrings.listSeparated(values, locale: chinese) == "深蹲、卧推")
    #expect(StudentStrings.listSeparated(["Squat", "Bench"], locale: english) == "Squat, Bench")
    #expect(StudentStrings.commaSeparated(values, locale: chinese) == "深蹲，卧推")
    #expect(StudentStrings.commaSeparated(["Squat", "Bench"], locale: english) == "Squat, Bench")
  }

  @Test("English count copy selects singular and plural catalog entries")
  func englishCountCopy() {
    #expect(
      StudentStrings.replacing(
        .dayCompletionBanner001,
        values: ["1"],
        locale: english
      ) == "Today's workout completed · 1 set"
    )
    #expect(
      StudentStrings.replacing(
        .dayCompletionBanner001,
        values: ["2"],
        locale: english
      ) == "Today's workout completed · 2 sets"
    )
    #expect(
      StudentStrings.replacing(
        .feedbackVideoPresentation002,
        values: ["120", "1"],
        locale: english
      ) == "120 kg × 1 rep"
    )
  }

  @Test("English count copy uses the designated placeholder")
  func englishCountCopyPlaceholder() {
    #expect(
      StudentStrings.replacing(
        .step4EnvironmentSection006,
        values: ["1"],
        locale: english
      ) == "1 day/week selected — Select at least 2 days"
    )
    #expect(
      StudentStrings.replacing(
        .historyEntriesView004,
        values: ["0", "1"],
        locale: english
      ) == "0/1 set"
    )
    #expect(
      StudentStrings.replacing(
        .trainingCalendarView002,
        values: ["0", "1"],
        locale: english
      ) == "Completed 0 / 1 session"
    )
    #expect(
      StudentStrings.replacing(
        .trainingCalendarView003,
        values: ["0", "1"],
        locale: english
      ) == "0 / 1 session"
    )
    #expect(
      StudentStrings.replacing(
        .dashboardPrimaryAction007,
        values: ["1", "1"],
        locale: english
      ) == "W1–W1 · 1 session total"
    )
  }

  @Test("Catalog exercise names use nameEn only for English display")
  func catalogExerciseNames() {
    let exercise = Exercise(
      id: UUID(),
      name: "暂停深蹲",
      nameEn: "Pause Squat",
      exerciseType: .mainLiftVariation,
      mainLiftFamily: .squat,
      isCompetitionLift: false,
      muscleGroups: [.quad],
      equipment: [.barbell],
      createdAt: Date(timeIntervalSince1970: 0)
    )

    #expect(StudentExerciseName.display(exercise, locale: chinese) == "暂停深蹲")
    #expect(StudentExerciseName.display(exercise, locale: english) == "Pause Squat")

    let video = CoachFeedbackVideo(
      id: UUID(),
      exerciseName: "暂停深蹲",
      exerciseNameEn: "Pause Squat"
    )
    #expect(StudentExerciseName.display(video, locale: chinese) == "暂停深蹲")
    #expect(StudentExerciseName.display(video, locale: english) == "Pause Squat")
  }
}
