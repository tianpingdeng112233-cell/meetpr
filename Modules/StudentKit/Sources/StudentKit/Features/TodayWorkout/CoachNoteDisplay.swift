import DesignSystem
import Foundation
import SwiftUI

enum CoachNoteDisplay {
  static func heroExerciseNote(isEditable: Bool, notes: String?) -> String? {
    isEditable ? text(notes) : nil
  }

  static func heroLowerNote(isEditable: Bool, notes: String?, coachNote: String?) -> String? {
    text(isEditable ? coachNote : notes)
  }

  static func text(_ raw: String?) -> String? {
    guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
      !trimmed.isEmpty
    else { return nil }
    return trimmed
  }

  /// The exercise-card note is a review-path affordance: while any set is still
  /// active the hero card owns the note (David 2026-07-18), so the card shows
  /// it only when the day has no active set (finished or browsed read-only).
  static func reviewNote(activeIndex: Int?, notes: String?) -> String? {
    guard activeIndex == nil else { return nil }
    return text(notes)
  }
}

/// Exercise-level coach note (web editor 备注 column) — muted label above the
/// free-wrapping note text. Shared by the active-set hero, the completed-day
/// exercise cards, and the history day detail.
struct CoachNotePill: View {
  let note: String
  /// Surface behind the pill — bump to `surfaceElevated` when the pill itself
  /// sits on a `surfaceCard` (e.g. history day detail) so it stays visible.
  var background: Color = Color.MeetPR.surfaceCard

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(StudentStrings.localized(.coachNoteDisplay001))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size10, weight: .medium))
        .tracking(0.8)
        .foregroundStyle(Color.MeetPR.textMuted)
      Text(note)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .medium))
        .foregroundStyle(Color.MeetPR.textPrimary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(background)
    .clipShape(.rect(cornerRadius: 8))
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(StudentStrings.replacing(.coachNoteDisplay002, values: ["\(note)"]))
  }
}

/// Only the editable hero promotes the exercise cue; read-only cards keep their existing pill.
struct HeroCoachNote: View {
  let note: String

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      Label(StudentStrings.localized(.coachNoteDisplay001), systemImage: "text.bubble")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .bold))
        .foregroundStyle(Color.MeetPR.goldText)
      Text(note)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .medium))
        .lineSpacing(MeetPRSpacing.point6)
        .foregroundStyle(Color.MeetPR.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(MeetPRSpacing.space3)
    .background(Color.MeetPR.goldRGB.opacity(0.12), in: .rect(cornerRadius: MeetPRRadius.inset))
    .accessibilityElement(children: .combine)
  }
}
