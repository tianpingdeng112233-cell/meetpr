import DesignSystem
import Foundation
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct DayChipBar: View {
  private let days: [DraftPlanDay]
  private let currentDayID: UUID?
  private let onSelect: @MainActor (UUID) -> Void

  public init(
    days: [DraftPlanDay],
    currentDayID: UUID?,
    onSelect: @escaping @MainActor (UUID) -> Void
  ) {
    self.days = days
    self.currentDayID = currentDayID
    self.onSelect = onSelect
  }

  public var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: MeetPRSpacing.sm) {
        ForEach(days, id: \.id) { day in
          DayChip(
            title: PlanningDisplay.weekdayName(day.dayOfWeek),
            isSelected: day.id == currentDayID
          ) {
            onSelect(day.id)
          }
        }
      }
      .padding(.horizontal, MeetPRSpacing.base)
    }
    .contentMargins(.vertical, MeetPRSpacing.xs)
    .scrollIndicators(.hidden)
  }
}

@MainActor
private struct DayChip: View {
  let title: String
  let isSelected: Bool
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(isSelected ? Color.MeetPR.bg : Color.MeetPR.fgPrimary)
        .lineLimit(1)
        .padding(.horizontal, MeetPRSpacing.base)
        .padding(.vertical, MeetPRSpacing.sm)
        .background(isSelected ? Color.MeetPR.fgPrimary : Color.MeetPR.surface2)
        .overlay {
          Capsule()
            .stroke(isSelected ? Color.MeetPR.fgPrimary : Color.MeetPR.border, lineWidth: 1)
        }
        .clipShape(.capsule)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
  }
}
