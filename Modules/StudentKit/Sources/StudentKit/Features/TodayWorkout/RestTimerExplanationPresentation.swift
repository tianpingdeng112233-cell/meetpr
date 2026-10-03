import Foundation

struct RestTimerExplanationPresentation: Sendable {
  struct Row: Identifiable, Sendable {
    let id: Int
    let condition: String
    let seconds: Int

    var duration: String { StudentRestTimerCopy.durationText(seconds) }
  }

  let rows: [Row]

  init(restSeconds: (Decimal) -> Int = { RestTimerPolicy.restSeconds(forRPE: $0) }) {
    rows = [
      Row(
        id: 0, condition: StudentStrings.localized(.restExplanationLow),
        seconds: restSeconds(Decimal(65) / 10)),
      Row(id: 1, condition: StudentStrings.localized(.restExplanationMid), seconds: restSeconds(7)),
      Row(
        id: 2, condition: StudentStrings.localized(.restExplanationHigh), seconds: restSeconds(9)),
    ]
  }
}
