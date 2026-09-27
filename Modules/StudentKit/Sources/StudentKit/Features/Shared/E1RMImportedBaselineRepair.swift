import CoreModels
import Foundation

/// Detect the old imported-baseline trap from canonical logs, without a migration
/// marker. A successful repair makes the first measured point normal, so retries
/// naturally stop; failed/CAS-rejected writes remain eligible on the next refresh.
enum E1RMImportedBaselineRepair {
  static func affectedFamilies(
    setLogs: [StudentSetLog],
    context: E1RMHistoryReplayContext
  ) -> Set<LiftFamily> {
    let eligibleLogs = setLogs.filter {
      !$0.assumed && E1RMCoachRPEReconciler.shouldProducePoint(for: $0, context: context)
    }.sorted {
      if $0.loggedAt != $1.loggedAt { return $0.loggedAt < $1.loggedAt }
      return $0.id.uuidString < $1.id.uuidString
    }
    var seen: Set<LiftFamily> = []
    var affected: Set<LiftFamily> = []
    for log in eligibleLogs {
      guard let exerciseID = context.exerciseID(for: log),
        let exercise = context.exerciseByID[exerciseID],
        let family = resolveCompetitionFamily(exercise: exercise, onboarding: context.profile),
        seen.insert(family).inserted,
        let point = context.existingPointBySetLogID[log.id],
        point.origin == .logged, point.confidence == .low
      else { continue }
      let hasEarlierImport = context.preservedPoints.contains {
        resolvedFamily(for: $0, context: context) == family
          && $0.confidence == .normal && $0.computedAt <= log.loggedAt
          && E1RMEligibility.isEligible(point: $0, family: family)
      }
      if hasEarlierImport { affected.insert(family) }
    }
    return affected
  }

  static func merging(
    _ replayed: E1RMHistoryReplayService.Result,
    into existing: E1RMHistoryReplayService.Result,
    families: Set<LiftFamily>,
    setLogs: [StudentSetLog],
    context: E1RMHistoryReplayContext
  ) -> E1RMHistoryReplayService.Result {
    // Keep unrelated families, reviewed imports and records unavailable in the
    // current canonical log response byte-for-byte. Only replace measured points
    // from the affected families that were actually rebuilt.
    let replacements = Dictionary(
      replayed.points.filter {
        $0.origin == .logged && isAffected($0, families: families, context: context)
      }.map { ($0.setLogId, $0) },
      uniquingKeysWith: { _, latest in latest }
    )
    let canonicalIDs = Set(
      setLogs.filter {
        guard $0.completed, !$0.assumed, let family = context.family(for: $0) else { return false }
        return families.contains(family)
      }.map(\.id))
    let oldIDs = Set(existing.points.map(\.setLogId))
    let points =
      existing.points.compactMap { point -> E1RMHistoryPoint? in
        if let replacement = replacements[point.setLogId] { return replacement }
        // A calibration can make an available canonical log ineligible. Orphans
        // cannot be recomputed, so retain them rather than assuming deletion.
        if point.origin == .logged && canonicalIDs.contains(point.setLogId) { return nil }
        return point
      } + replacements.values.filter { !oldIDs.contains($0.setLogId) }
    return .init(
      points: points,
      weightBaselines: mergeBaselines(
        existing: existing.weightBaselines,
        replayed: replayed.weightBaselines.filter { families.contains($0.family) }
      )
    )
  }

  private static func mergeBaselines(
    existing: [E1RMWeightBaseline],
    replayed: [E1RMWeightBaseline]
  ) -> [E1RMWeightBaseline] {
    Dictionary(
      (existing + replayed).map { ($0.family, $0) },
      uniquingKeysWith: { old, new in
        old.maxWeightKg >= new.maxWeightKg ? old : new
      }
    ).values.sorted { $0.family.rawValue < $1.family.rawValue }
  }

  private static func isAffected(
    _ point: E1RMHistoryPoint,
    families: Set<LiftFamily>,
    context: E1RMHistoryReplayContext
  ) -> Bool {
    guard let family = resolvedFamily(for: point, context: context) else { return false }
    return families.contains(family)
  }

  private static func resolvedFamily(
    for point: E1RMHistoryPoint,
    context: E1RMHistoryReplayContext
  ) -> LiftFamily? {
    if let family = point.family { return family }
    guard let exercise = context.exerciseByID[point.exerciseId] else { return nil }
    return resolveCompetitionFamily(exercise: exercise, onboarding: context.profile)
  }
}

extension E1RMHistoryReplayContext {
  func family(for log: StudentSetLog) -> LiftFamily? {
    guard let id = exerciseID(for: log), let exercise = exerciseByID[id] else { return nil }
    return resolveCompetitionFamily(exercise: exercise, onboarding: profile)
  }
}
