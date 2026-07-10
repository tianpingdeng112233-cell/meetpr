import CoreModels

enum SetDisplayNumber {
  static func number(atOffset offset: Int) -> Int {
    offset + 1
  }

  static func number(for draft: TodayWorkoutSetRowDraft, in rows: [TodayWorkoutSetRowDraft]) -> Int
  {
    rows.firstIndex { $0.id == draft.id }.map(number(atOffset:))
      ?? fallback(storedIndex: draft.prescribed.setIndex)
  }

  static func number(for set: PrescribedSet, in sets: [PrescribedSet]) -> Int {
    sets.firstIndex { $0.id == set.id }.map(number(atOffset:))
      ?? fallback(storedIndex: set.setIndex)
  }

  private static func fallback(storedIndex: Int) -> Int {
    max(1, storedIndex)
  }
}
