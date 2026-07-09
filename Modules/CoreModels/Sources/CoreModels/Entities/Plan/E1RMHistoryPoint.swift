import Foundation

/// Trust tier for an e1RM point (spec 050 §5). `.low` points are quarantined —
/// kept for honest scatter but excluded from current/best/PR so a single
/// mis-logged set never poisons the headline strength number.
public enum E1RMConfidence: String, Codable, Hashable, Sendable {
  case normal
  case low
}

/// Where an e1RM point came from. Imported history participates in the
/// trusted baseline when its confidence is `.normal`, but it is never a PR
/// event subject (spec 053).
public enum E1RMPointOrigin: String, Codable, Hashable, Sendable {
  case logged
  case imported
}

/// One estimated-1RM data point, computed locally each time the student
/// completes a set (spec 028). Distinct from the locked 1RM profile field:
/// e1RM is a per-set estimate and never writes back to 1RM (PRD §5 #16).
public struct E1RMHistoryPoint: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentId: UUID
  /// Catalog exercise identity (variation-level): squat / high-bar squat /
  /// lunge each keep an independent history and PR lineage.
  public let exerciseId: UUID
  public let setLogId: UUID
  public let computedAt: Date
  public let e1RMKg: Double
  public let sourceWeightKg: Double
  public let sourceReps: Int
  public let sourceRPE: Double?
  /// Anomaly-guard tier (spec 050 §5). Points persisted before the guard have
  /// no `confidence` key and decode as `.normal` — no backend/data migration.
  public let confidence: E1RMConfidence
  /// Persisted points created before imported-history support have no `origin`
  /// key and decode as `.logged` for backward compatibility.
  public let origin: E1RMPointOrigin

  public init(
    id: UUID,
    studentId: UUID,
    exerciseId: UUID,
    setLogId: UUID,
    computedAt: Date,
    e1RMKg: Double,
    sourceWeightKg: Double,
    sourceReps: Int,
    sourceRPE: Double?,
    confidence: E1RMConfidence = .normal,
    origin: E1RMPointOrigin = .logged
  ) {
    self.id = id
    self.studentId = studentId
    self.exerciseId = exerciseId
    self.setLogId = setLogId
    self.computedAt = computedAt
    self.e1RMKg = e1RMKg
    self.sourceWeightKg = sourceWeightKg
    self.sourceReps = sourceReps
    self.sourceRPE = sourceRPE
    self.confidence = confidence
    self.origin = origin
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    studentId = try container.decode(UUID.self, forKey: .studentId)
    exerciseId = try container.decode(UUID.self, forKey: .exerciseId)
    setLogId = try container.decode(UUID.self, forKey: .setLogId)
    computedAt = try container.decode(Date.self, forKey: .computedAt)
    e1RMKg = try container.decode(Double.self, forKey: .e1RMKg)
    sourceWeightKg = try container.decode(Double.self, forKey: .sourceWeightKg)
    sourceReps = try container.decode(Int.self, forKey: .sourceReps)
    sourceRPE = try container.decodeIfPresent(Double.self, forKey: .sourceRPE)
    confidence = try container.decodeIfPresent(E1RMConfidence.self, forKey: .confidence) ?? .normal
    origin = try container.decodeIfPresent(E1RMPointOrigin.self, forKey: .origin) ?? .logged
  }
}

extension E1RMHistoryPoint {
  /// Keeps the original stable point identity while replacing the set-log
  /// payload (for example when an assumed row becomes a real logged row).
  public func replacing(id: UUID) -> E1RMHistoryPoint {
    E1RMHistoryPoint(
      id: id,
      studentId: studentId,
      exerciseId: exerciseId,
      setLogId: setLogId,
      computedAt: computedAt,
      e1RMKg: e1RMKg,
      sourceWeightKg: sourceWeightKg,
      sourceReps: sourceReps,
      sourceRPE: sourceRPE,
      confidence: confidence,
      origin: origin
    )
  }

  /// Changes only the trust tier after the student reviews an imported batch.
  public func replacing(confidence: E1RMConfidence) -> E1RMHistoryPoint {
    E1RMHistoryPoint(
      id: id,
      studentId: studentId,
      exerciseId: exerciseId,
      setLogId: setLogId,
      computedAt: computedAt,
      e1RMKg: e1RMKg,
      sourceWeightKg: sourceWeightKg,
      sourceReps: sourceReps,
      sourceRPE: sourceRPE,
      confidence: confidence,
      origin: origin
    )
  }
}
