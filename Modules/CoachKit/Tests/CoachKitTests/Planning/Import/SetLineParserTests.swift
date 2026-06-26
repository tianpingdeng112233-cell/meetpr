import CoreModels
import Foundation
import Testing

@testable import CoachKit

// spec 043 解析规则附录 — golden expansions. Numbers are copied verbatim; the
// parser never computes a weight.

private func dec(_ string: String) -> Decimal { Decimal(string: string)! }
private func weights(_ sets: [ParsedSet]) -> [Decimal?] { sets.map(\.weightKg) }
private func rpes(_ sets: [ParsedSet]) -> [Decimal?] { sets.map(\.rpe) }
private func notes(_ sets: [ParsedSet]) -> [String?] { sets.map(\.coachNote) }

@Test func parsesSetsAndRepsForms() {
  #expect(
    SetLineParser.parseSetsReps("4*8")
      == SetCountReps(count: 4, reps: 8, repsMax: nil, openEnded: false))
  #expect(
    SetLineParser.parseSetsReps("4*8-12")
      == SetCountReps(count: 4, reps: 8, repsMax: 12, openEnded: false))
  #expect(
    SetLineParser.parseSetsReps("4组")
      == SetCountReps(count: 4, reps: nil, repsMax: nil, openEnded: true))
  #expect(SetLineParser.parseSetsReps("") == nil)
}

@Test func ladderClampsAtCap() {
  #expect(
    weights(SetLineParser.expand(setsCell: "4*3", intensityCell: "D100/L110 递增5kg"))
      == [dec("100"), dec("105"), dec("110"), dec("110")])
  #expect(
    weights(SetLineParser.expand(setsCell: "4*3", intensityCell: "D80/L90 递增5kg"))
      == [dec("80"), dec("85"), dec("90"), dec("90")])
}

@Test func ladderHandlesFractionalStep() {
  #expect(
    weights(SetLineParser.expand(setsCell: "4*3", intensityCell: "D62.5/L70 递增2.5kg"))
      == [dec("62.5"), dec("65"), dec("67.5"), dec("70")])
}

@Test func perSetWeightList() {
  #expect(
    weights(SetLineParser.expand(setsCell: "4*3", intensityCell: "120/125/130/135"))
      == [dec("120"), dec("125"), dec("130"), dec("135")])
}

@Test func singleWeightAppliesToEverySet() {
  #expect(
    weights(SetLineParser.expand(setsCell: "3*3", intensityCell: "125"))
      == [dec("125"), dec("125"), dec("125")])
}

@Test func perSetRPEFromFloatDigits() {
  #expect(
    rpes(SetLineParser.expand(setsCell: "4*8", intensityCell: "", float1: "6789"))
      == [dec("6"), dec("7"), dec("8"), dec("9")])
  #expect(
    rpes(SetLineParser.expand(setsCell: "4*8", intensityCell: "", float1: "6788"))
      == [dec("6"), dec("7"), dec("8"), dec("8")])
}

@Test func sharedRPE() {
  #expect(
    rpes(SetLineParser.expand(setsCell: "4*5", intensityCell: "rpe9"))
      == [dec("9"), dec("9"), dec("9"), dec("9")])
}

@Test func tempoFloatBecomesCoachNote() {
  let sets = SetLineParser.expand(
    setsCell: "4*5", intensityCell: "", float1: "310", exerciseName: "节奏深蹲")
  #expect(notes(sets) == Array(repeating: "节奏3-1-0", count: 4))
  #expect(weights(sets) == Array(repeating: Decimal?.none, count: 4))
}

@Test func tempoSuffixStrippedFromName() {
  let result = SetLineParser.stripTempoSuffix("节奏深蹲310")
  #expect(result.name == "节奏深蹲")
  #expect(result.tempoNote == "节奏3-1-0")
  // A non-tempo movement keeps its trailing digits untouched.
  #expect(SetLineParser.stripTempoSuffix("深蹲").tempoNote == nil)
}

@Test func percentTopLeftEmptyWithCue() {
  let sets = SetLineParser.expand(setsCell: "3*3", intensityCell: "70%top")
  #expect(weights(sets) == Array(repeating: Decimal?.none, count: 3))
  #expect(notes(sets) == Array(repeating: "70%top", count: 3))
}

@Test func backoffKeepsCueAndType() {
  let sets = SetLineParser.expand(setsCell: "2*5", intensityCell: "减10kg*2")
  #expect(sets.allSatisfy { $0.setType == .backoff })
  #expect(sets.allSatisfy { $0.weightKg == nil })
  #expect(notes(sets) == ["减10kg*2", "减10kg*2"])
}

@Test func amrapDefersRepsAndKeepsCue() {
  let sets = SetLineParser.expand(setsCell: "4组", intensityCell: "力竭")
  #expect(sets.count == 4)
  #expect(sets.allSatisfy { $0.setType == .amrap })
  #expect(sets.allSatisfy { $0.reps == nil })
  #expect(notes(sets) == Array(repeating: "力竭", count: 4))
}
