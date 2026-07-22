import Foundation

/// One muscle group the student marks as sore, with a 1-4 severity
/// (轻微/中等/明显酸痛/严重酸痛). Only
/// `ReadinessCheckin.allowedMuscleGroups` are legal.
public struct MuscleFatigue: Codable, Hashable, Sendable {
  public let muscleGroup: MuscleGroup
  /// 1 轻微 / 2 中等 / 3 明显酸痛 / 4 严重酸痛
  public let severity: Int

  public init(muscleGroup: MuscleGroup, severity: Int) {
    self.muscleGroup = muscleGroup
    self.severity = severity
  }
}

/// Daily pre-workout readiness check-in (spec 030 §C). Collected and shown
/// to the coach as raw values — no readiness score, no plan adjustment
/// (ADR-001 data-first red line).
public struct ReadinessCheckin: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentId: UUID
  /// Student-local calendar day "yyyy-MM-dd". A String, not a Date: encoding
  /// a calendar-day as Date+ISO8601 invites UTC-midnight timezone bugs.
  public let checkinDate: String
  /// 1-5, 5 = best.
  public let sleepQuality: Int
  /// 1-5, 5 = most energetic. Optional for records submitted before energy
  /// was added to the readiness check-in.
  public let energy: Int?
  /// 1-5, 5 = best.
  public let mood: Int
  /// 1-5, 5 = most relaxed — all four scales point the same way so the coach
  /// never mentally inverts one. The stress UI inverts its anchor copy only.
  public let stress: Int
  public let muscleFatigue: [MuscleFatigue]
  public let submittedAt: Date

  public init(
    id: UUID,
    studentId: UUID,
    checkinDate: String,
    sleepQuality: Int,
    energy: Int? = nil,
    mood: Int,
    stress: Int,
    muscleFatigue: [MuscleFatigue],
    submittedAt: Date
  ) {
    self.id = id
    self.studentId = studentId
    self.checkinDate = checkinDate
    self.sleepQuality = sleepQuality
    self.energy = energy
    self.mood = mood
    self.stress = stress
    self.muscleFatigue = muscleFatigue
    self.submittedAt = submittedAt
  }

  /// Powerlifting-relevant whitelist — the single source of truth for chip
  /// order and validation on both ends; the backend zod whitelist mirrors
  /// these raw values verbatim.
  public static let allowedMuscleGroups: [MuscleGroup] = [
    .quad, .hamstring, .glute, .back, .chest, .shoulder, .triceps, .core,
  ]
}
