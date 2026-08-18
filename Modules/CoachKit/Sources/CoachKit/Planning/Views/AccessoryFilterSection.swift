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
        Text(CoachPlanningStrings.filter)
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)

        muscleGroupRow
        equipmentRow
        movementPatternRow
      }
    }
  }

  private var muscleGroupRow: some View {
    FilterRow(title: CoachPlanningStrings.muscleGroup) {
      FilterChip(title: CoachPlanningStrings.all, isSelected: filters.muscleGroups.isEmpty) {
        var nextFilters = filters
        nextFilters.muscleGroups = []
        onChange(nextFilters)
      }

      ForEach(MuscleGroupChip.allCases, id: \.self) { chip in
        FilterChip(
          title: chip.displayName,
          isSelected: chip.underlyingMuscleGroups.isSubset(of: filters.muscleGroups)
        ) {
          var nextFilters = filters
          if chip.underlyingMuscleGroups.isSubset(of: nextFilters.muscleGroups) {
            nextFilters.muscleGroups.subtract(chip.underlyingMuscleGroups)
          } else {
            nextFilters.muscleGroups.formUnion(chip.underlyingMuscleGroups)
          }
          onChange(nextFilters)
        }
      }
    }
  }

  private var equipmentRow: some View {
    FilterRow(title: CoachPlanningStrings.equipment) {
      FilterChip(title: CoachPlanningStrings.all, isSelected: filters.equipment.isEmpty) {
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
    FilterRow(title: CoachPlanningStrings.movementPattern) {
      FilterChip(title: CoachPlanningStrings.all, isSelected: filters.movementPatterns.isEmpty) {
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

/// Display-layer grouping for muscle filter chips. Folds `hipFlexor` into `hip`
/// and the long tail (`tibialis` / `trap` / `mobility` / `cardio` / `grip`) into
/// a single "其他" chip so the filter strip stays short and meaningful.
enum MuscleGroupChip: CaseIterable, Hashable {
  case chest
  case shoulder
  case back
  case biceps
  case triceps
  case forearm
  case core
  case quad
  case hamstring
  case glute
  case hip
  case adductor
  case calf
  case other

  var displayName: String {
    switch self {
    case .chest: CoachPlanningStrings.chest
    case .shoulder: CoachPlanningStrings.shoulder
    case .back: CoachPlanningStrings.back
    case .biceps: CoachPlanningStrings.biceps
    case .triceps: CoachPlanningStrings.triceps
    case .forearm: CoachPlanningStrings.forearm
    case .core: CoachPlanningStrings.core
    case .quad: CoachPlanningStrings.quadriceps
    case .hamstring: CoachPlanningStrings.hamstrings
    case .glute: CoachPlanningStrings.glutes
    case .hip: CoachPlanningStrings.hip
    case .adductor: CoachPlanningStrings.adductors
    case .calf: CoachPlanningStrings.calves
    case .other: CoachPlanningStrings.other
    }
  }

  var underlyingMuscleGroups: Set<MuscleGroup> {
    switch self {
    case .chest: [.chest]
    case .shoulder: [.shoulder]
    case .back: [.back]
    case .biceps: [.biceps]
    case .triceps: [.triceps]
    case .forearm: [.forearm]
    case .core: [.core]
    case .quad: [.quad]
    case .hamstring: [.hamstring]
    case .glute: [.glute]
    case .hip: [.hip, .hipFlexor]
    case .adductor: [.adductor]
    case .calf: [.calf]
    case .other: [.tibialis, .trap, .mobility, .cardio, .grip]
    }
  }
}
