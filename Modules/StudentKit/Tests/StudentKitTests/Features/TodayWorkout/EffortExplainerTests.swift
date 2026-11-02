import Foundation
import Testing

@testable import StudentKit

@Suite struct EffortExplainerTests {
  @Test func cardsMatchApprovedCopyWithoutCrossReferencingTheOtherScale() {
    let chinese = Locale(identifier: "zh-Hans")
    let english = Locale(identifier: "en")
    let rpe = EffortExplainer.content(for: .rpe, locale: chinese)
    #expect(rpe.title == "RPE · 这组有多吃力")
    #expect(rpe.subtitle == "满分 10，越高越吃力")
    #expect(rpe.rows.map(\.value) == ["10", "9.5", "9", "8.5", "8", "7.5", "7", "5–6"])
    #expect(
      rpe.rows.map(\.description) == [
        "做不动了", "做不了下一次，但能再加点重", "还剩 1 次", "还剩 1–2 次",
        "还剩 2 次", "还剩 2–3 次", "还剩 3 次", "还剩 4–6 次",
      ])
    #expect(rpe.closing == "估不准没关系，选最接近的就行")
    #expect(rpe.example == nil)
    #expect(rpe.helpLabel == "RPE 是什么")
    let rpeEnglish = EffortExplainer.content(for: .rpe, locale: english)
    #expect(rpeEnglish.title == "RPE · How hard was that set")
    #expect(rpeEnglish.subtitle == "Out of 10. Higher means harder.")
    #expect(
      rpeEnglish.rows.map(\.description) == [
        "Couldn't do another rep", "No more reps, but could add a little weight",
        "1 rep left", "1–2 reps left", "2 reps left", "2–3 reps left", "3 reps left",
        "4–6 reps left",
      ])
    #expect(rpeEnglish.closing == "Not sure? Pick the closest one.")
    #expect(rpeEnglish.helpLabel == "What is RPE")

    let rir = EffortExplainer.content(for: .rir, locale: chinese)
    #expect(rir.title == "RIR · 还能再做几次")
    #expect(rir.subtitle == "这组做完，同样的重量还能再做几次，就填几")
    #expect(rir.rows.isEmpty)
    #expect(rir.example == "例：做了 6 次，觉得最多能做 8 次 → 填 2")
    #expect(rir.closing == "一次也做不动了就填 0")
    #expect(rir.helpLabel == "RIR 是什么")
    let rirEnglish = EffortExplainer.content(for: .rir, locale: english)
    #expect(rirEnglish.title == "RIR · Reps left in the tank")
    #expect(
      rirEnglish.subtitle
        == "After the set, how many more reps could you do with the same weight? Enter that number."
    )
    #expect(rirEnglish.example == "Example: you did 6 and could have done 8 → enter 2")
    #expect(rirEnglish.closing == "Couldn't do another rep? Enter 0.")
    #expect(rirEnglish.helpLabel == "What is RIR")
  }
}

@Suite struct RIRStepperCopyTests {
  @Test func hintUsesRemainingRepsWithoutRPEConversion() {
    let chinese = Locale(identifier: "zh-Hans")
    let english = Locale(identifier: "en")
    let examples = [
      ("0", "做不动了", "Couldn't do another rep"),
      ("1", "还剩 1 次", "1 rep left"),
      ("2", "还剩 2 次", "2 reps left"),
      ("9", "还剩 9 次", "9 reps left"),
    ]
    for (input, zhHans, englishCopy) in examples {
      #expect(EffortExplainer.rirStepperCopy(input, locale: chinese) == zhHans)
      #expect(EffortExplainer.rirStepperCopy(input, locale: english) == englishCopy)
    }
    #expect(EffortExplainer.rirStepperCopy("", locale: chinese) == nil)
    #expect(EffortExplainer.rirStepperCopy("", locale: english) == nil)
    for invalid in ["-1", "10", "1.5", "abc"] {
      #expect(EffortExplainer.rirStepperCopy(invalid, locale: english) == nil)
    }
  }
}
