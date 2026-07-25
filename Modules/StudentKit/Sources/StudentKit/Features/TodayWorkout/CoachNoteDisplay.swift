import DesignSystem
import Foundation
import SwiftUI

enum CoachNoteDisplay {
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
  /// Surface behind the pill — bump to `surface2` when the pill itself sits on
  /// a `surface1` card (e.g. history day detail) so it stays visible.
  var background: Color = Color.MeetPR.bgInset

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      Text("教练备注")
        .font(.MeetPR.mono(size: 11, weight: .medium))
        .tracking(0.8)
        .foregroundStyle(Color.MeetPR.textTertiary)
      Text(note)
        .font(.MeetPR.body(size: 12, weight: .medium))
        .foregroundStyle(Color.MeetPR.coachNoteText)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, MeetPRSpacing.point10)
    .padding(.vertical, MeetPRSpacing.space2)
    .background(background)
    .clipShape(.rect(cornerRadius: MeetPRRadius.chip))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.chip)
        .stroke(Color.MeetPR.borderSubtle, lineWidth: 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("教练备注 \(note)")
  }
}
