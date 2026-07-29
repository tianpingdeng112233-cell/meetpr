import Foundation

/// Metadata for the training video a coach feedback item refers to.
///
/// Everything but `id` is optional on purpose. Server-side this metadata comes
/// from left joins (attachment → set log → exercise), and a freely recorded
/// clip — one uploaded without a `set_log_id`, which spec 025 explicitly allows
/// feedback on — resolves every one of them to null. Declaring any of these
/// non-optional would fail the whole `items` decode on such a row and blank the
/// student's entire inbox, not just this card.
public struct CoachFeedbackVideo: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let exerciseName: String?
  public let setIndex: Int?
  public let weightKg: String?
  public let reps: Int?
  public let loggedAt: Date?
  /// Clip duration when the feedback projection can provide it.
  ///
  /// Older backend payloads omit this field, so the student chat keeps it
  /// optional and renders a neutral placeholder when unavailable.
  public let durationSeconds: Int?

  public init(
    id: UUID,
    exerciseName: String? = nil,
    setIndex: Int? = nil,
    weightKg: String? = nil,
    reps: Int? = nil,
    loggedAt: Date? = nil,
    durationSeconds: Int? = nil
  ) {
    self.id = id
    self.exerciseName = exerciseName
    self.setIndex = setIndex
    self.weightKg = weightKg
    self.reps = reps
    self.loggedAt = loggedAt
    self.durationSeconds = durationSeconds
  }
}
