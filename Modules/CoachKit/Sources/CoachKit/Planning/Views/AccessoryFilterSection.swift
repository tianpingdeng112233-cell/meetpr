import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct AccessoryFilterSection: View {
  private let filters: AccessoryFilters
  private let onChange: @MainActor (AccessoryFilters) -> Void

  public init(
    filters: AccessoryFilters,
    onChange: @escaping @MainActor (AccessoryFilters) -> Void
  ) {
    self.filters = filters
    self.onChange = onChange
  }

  public var body: some View {
    Card(accessibilityLabel: "Accessory filters") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        Text("筛选")
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)

        muscleGroupRow
        equipmentRow
        movementPatternRow
      }
    }
  }

  private var muscleGroupRow: some View {
    FilterRow(title: "肌群") {
      FilterChip(title: "全部", isSelected: filters.muscleGroups.isEmpty) {
        var nextFilters = filters
        nextFilters.muscleGroups = []
        onChange(nextFilters)
      }

      ForEach(MuscleGroup.allCases, id: \.self) { muscleGroup in
        FilterChip(
          title: PlanningDisplay.muscleGroupName(muscleGroup),
          isSelected: filters.muscleGroups.contains(muscleGroup)
        ) {
          var nextFilters = filters
          nextFilters.muscleGroups.toggle(muscleGroup)
          onChange(nextFilters)
        }
      }
    }
  }

  private var equipmentRow: some View {
    FilterRow(title: "器械") {
      FilterChip(title: "全部", isSelected: filters.equipment.isEmpty) {
        var nextFilters = filters
        nextFilters.equipment = []
        onChange(nextFilters)
      }

      ForEach(Equipment.allCases, id: \.self) { equipment in
        FilterChip(
          title: PlanningDisplay.equipmentName(equipment),
          isSelected: filters.equipment.contains(equipment)
        ) {
          var nextFilters = filters
          nextFilters.equipment.toggle(equipment)
          onChange(nextFilters)
        }
      }
    }
  }

  private var movementPatternRow: some View {
    FilterRow(title: "模式") {
      FilterChip(title: "全部", isSelected: filters.movementPatterns.isEmpty) {
        var nextFilters = filters
        nextFilters.movementPatterns = []
        onChange(nextFilters)
      }

      ForEach(MovementPattern.allCases, id: \.self) { movementPattern in
        FilterChip(
          title: PlanningDisplay.movementPatternName(movementPattern),
          isSelected: filters.movementPatterns.contains(movementPattern)
        ) {
          var nextFilters = filters
          nextFilters.movementPatterns.toggle(movementPattern)
          onChange(nextFilters)
        }
      }
    }
  }
}

@MainActor
private struct FilterRow<Content: View>: View {
  let title: String
  let content: Content

  init(title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Text(title)
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)

      ScrollView(.horizontal) {
        HStack(spacing: MeetPRSpacing.sm) {
          content
        }
        .padding(.vertical, 1)
      }
      .scrollIndicators(.hidden)
    }
  }
}

@MainActor
private struct FilterChip: View {
  let title: String
  let isSelected: Bool
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(Font.MeetPR.footnote)
        .foregroundStyle(isSelected ? Color.MeetPR.bg : Color.MeetPR.fgPrimary)
        .lineLimit(1)
        .padding(.horizontal, MeetPRSpacing.md)
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

extension Set {
  fileprivate mutating func toggle(_ member: Element) {
    if contains(member) {
      remove(member)
    } else {
      insert(member)
    }
  }
}
