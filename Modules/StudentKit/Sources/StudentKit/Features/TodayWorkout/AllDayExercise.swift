import Foundation

struct AllDayExercise: Identifiable, Equatable, Sendable {
  enum Node: Sendable { case completed, current, pending }
  let id: UUID
  let rows: [TodayWorkoutSetRowDraft]
  let node: Node
  var hidesName = false
  var isCollapsed: Bool { node == .completed }
  var lastSet: TodayWorkoutSetRowDraft? { rows.last }

  static func build(
    drafts: [TodayWorkoutSetRowDraft], collapsed: Set<UUID>
  ) -> [Self] {
    var order: [UUID] = []
    var groups: [UUID: [TodayWorkoutSetRowDraft]] = [:]
    for draft in drafts {
      if groups[draft.planExerciseID] == nil { order.append(draft.planExerciseID) }
      groups[draft.planExerciseID, default: []].append(draft)
    }
    let current = order.first { !collapsed.contains($0) }
    return order.enumerated().map { index, id in
      Self(
        id: id,
        rows: (groups[id] ?? []).sorted {
          if $0.isWarmup != $1.isWarmup { return $0.isWarmup }
          return $0.prescribed.setIndex < $1.prescribed.setIndex
        },
        node: collapsed.contains(id) ? .completed : id == current ? .current : .pending,
        hidesName: index > 0
          && groups[order[index - 1]]?.first?.exerciseID == groups[id]?.first?.exerciseID)
    }
  }
}
