import CoreModels
import Foundation

enum PctAnchorUnresolvedReason: Equatable, Sendable {
  case unsupportedExercise
  case missingRegisteredOneRM
  case topSetNotCompleted
}

enum PctAnchorResolutionSource: Equatable, Sendable {
  case registeredOneRM(anchorKg: Decimal)
  case e1RM(anchorKg: Decimal)
  case topSet(anchorKg: Decimal)
  case fallbackToRegisteredOneRM(anchorKg: Decimal)
  case unresolved(PctAnchorUnresolvedReason)

  var anchorKg: Decimal? {
    switch self {
    case .registeredOneRM(let anchorKg), .e1RM(let anchorKg),
      .topSet(let anchorKg), .fallbackToRegisteredOneRM(let anchorKg):
      anchorKg
    case .unresolved:
      nil
    }
  }
}

struct PctAnchorResolution: Equatable, Sendable {
  let resolvedKg: Decimal?
  let source: PctAnchorResolutionSource
}

enum PctAnchorResolver {
  struct LoggedSet: Equatable, Sendable {
    let exerciseID: UUID
    let planExerciseSortOrder: Int
    let actualWeightKg: Decimal?
    let actualReps: Int?
    let completed: Bool
    let failed: Bool
  }

  struct Input: Equatable, Sendable {
    let percentage: Decimal
    let anchor: PercentageAnchor
    let exerciseFamily: LiftFamily?
    let registeredOneRMKg: Decimal?
    let currentE1RMKg: Double?
    let exerciseID: UUID
    let planExerciseSortOrder: Int
    let sameDaySets: [LoggedSet]
  }

  static func resolve(_ input: Input) -> PctAnchorResolution {
    guard input.exerciseFamily != nil else {
      return unresolved(.unsupportedExercise)
    }

    switch input.anchor {
    case .registeredOneRM:
      guard let registered = positive(input.registeredOneRMKg) else {
        return unresolved(.missingRegisteredOneRM)
      }
      return resolved(
        percentage: input.percentage,
        anchorKg: registered,
        source: .registeredOneRM(anchorKg: registered)
      )

    case .e1RM:
      if let current = input.currentE1RMKg, current > 0 {
        let anchor = NSDecimalNumber(value: current).decimalValue
        return resolved(
          percentage: input.percentage,
          anchorKg: anchor,
          source: .e1RM(anchorKg: anchor)
        )
      }
      guard let registered = positive(input.registeredOneRMKg) else {
        return unresolved(.missingRegisteredOneRM)
      }
      return resolved(
        percentage: input.percentage,
        anchorKg: registered,
        source: .fallbackToRegisteredOneRM(anchorKg: registered)
      )

    case .topSet:
      let anchor = input.sameDaySets.compactMap { set -> Decimal? in
        guard set.exerciseID == input.exerciseID,
          set.planExerciseSortOrder < input.planExerciseSortOrder,
          set.completed,
          !set.failed,
          set.actualReps.map({ $0 >= 1 }) == true,
          let weight = set.actualWeightKg,
          weight > 0
        else { return nil }
        return weight
      }.max()
      guard let anchor else { return unresolved(.topSetNotCompleted) }
      return resolved(
        percentage: input.percentage,
        anchorKg: anchor,
        source: .topSet(anchorKg: anchor)
      )
    }
  }

  private static func resolved(
    percentage: Decimal,
    anchorKg: Decimal,
    source: PctAnchorResolutionSource
  ) -> PctAnchorResolution {
    let rawWeight =
      NSDecimalNumber(decimal: anchorKg).doubleValue
      * NSDecimalNumber(decimal: percentage).doubleValue / 100
    return PctAnchorResolution(
      resolvedKg: SetWeightSuggestionRounding.roundedDownToPlateStep(rawWeight),
      source: source
    )
  }

  private static func unresolved(
    _ reason: PctAnchorUnresolvedReason
  ) -> PctAnchorResolution {
    PctAnchorResolution(resolvedKg: nil, source: .unresolved(reason))
  }

  private static func positive(_ value: Decimal?) -> Decimal? {
    guard let value, value > 0 else { return nil }
    return value
  }
}

enum SetWeightSuggestionRounding {
  static func roundedDownToPlateStep(_ weight: Double) -> Decimal? {
    // Reversed e1RM and percentage products can land a hair under an exact
    // multiple through binary floating point. Preserve the established nudge.
    let steps = (weight / 2.5 + 1e-6).rounded(.down)
    let rounded = steps * 2.5
    guard rounded > 0 else { return nil }
    return Decimal(rounded)
  }
}
