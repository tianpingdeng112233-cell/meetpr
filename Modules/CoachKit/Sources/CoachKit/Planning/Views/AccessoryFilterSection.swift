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
          .foregroundStyle(Color.MeetPR.textPrimary)

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
        .foregroundStyle(Color.MeetPR.textSecondary)

      ScrollView(.horizontal) {
        HStack(spacing: MeetPRSpacing.sm) {
          content
        }
        .padding(.vertical, MeetPRSpacing.point1)
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
        .foregroundStyle(isSelected ? Color.MeetPR.bgBase : Color.MeetPR.textPrimary)
        .lineLimit(1)
        .padding(.horizontal, MeetPRSpacing.md)
        .padding(.vertical, MeetPRSpacing.sm)
        .background(isSelected ? Color.MeetPR.textPrimary : Color.MeetPR.surfaceElevated)
        .overlay {
          Capsule()
            .stroke(
              isSelected ? Color.MeetPR.textPrimary : Color.MeetPR.borderDefault, lineWidth: 1)
        }
        .clipShape(.capsule)
    }
    .buttonStyle(PressScaleButtonStyle())
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
    case .chest: "胸"
    case .shoulder: "肩"
    case .back: "背"
    case .biceps: "二头"
    case .triceps: "三头"
    case .forearm: "小臂"
    case .core: "核心"
    case .quad: "股四"
    case .hamstring: "腘绳"
    case .glute: "臀"
    case .hip: "髋"
    case .adductor: "内收"
    case .calf: "小腿"
    case .other: "其他"
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
