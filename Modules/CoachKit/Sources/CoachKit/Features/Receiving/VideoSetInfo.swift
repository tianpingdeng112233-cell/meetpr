import CoreModels
import Foundation

struct VideoSetInfo: Equatable, Sendable {
  let weightText: String
  let reps: Int
  let rpeText: String?
  let displaySetNumber: Int

  init(log: StudentSetLog) {
    weightText = Self.decimalText(log.weightKg)
    reps = log.reps
    rpeText = log.rpe.map(Self.decimalText)
    displaySetNumber = log.setIndex + 1
  }

  static func resolve(
    setLogID: UUID?,
    from logs: [StudentSetLog]
  ) -> VideoSetInfo? {
    guard let setLogID, let log = logs.first(where: { $0.id == setLogID }) else {
      return nil
    }
    return VideoSetInfo(log: log)
  }

  private static func decimalText(_ value: Decimal) -> String {
    value.formatted(
      .number
        .grouping(.never)
        .precision(.fractionLength(0...1))
        .locale(Locale(identifier: "en_US_POSIX"))
    )
  }
}
