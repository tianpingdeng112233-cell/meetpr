import Foundation

extension PrescribedSet {
  public var isBodyweight: Bool {
    if let loadMode { return loadMode == .bodyweight }
    return coachNote?.range(of: "自重|bodyweight", options: [.regularExpression, .caseInsensitive])
      != nil
  }

  public var hasUnspecifiedLoad: Bool { loadMode == .freeWeight || isBodyweight }

  /// Keep the coach's other cues when removing the legacy compatibility marker.
  public var visibleCoachNote: String? {
    guard let coachNote else { return nil }
    let note =
      isBodyweight
      ? coachNote.replacing(#/(?i)自重|bodyweight/#, with: "") : coachNote
    let trimmed = note.trimmingCharacters(
      in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: " ·,，;；|｜/")))
    return trimmed.isEmpty ? nil : trimmed
  }
}
