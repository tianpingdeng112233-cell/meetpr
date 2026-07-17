import CoreModels

struct TodayWorkoutExerciseSection: Equatable, Sendable, Identifiable {
  enum Kind: Hashable, Sendable {
    case mainLiftOrVariation
    case accessory
  }

  let kind: Kind
  let exercises: [StudentPlanExercise]

  var id: Kind {
    kind
  }

  var title: String {
    switch kind {
    case .mainLiftOrVariation:
      "主项及变式"
    case .accessory:
      "辅助项"
    }
  }

  static func sections(
    for exercises: [StudentPlanExercise]
  ) -> [TodayWorkoutExerciseSection] {
    let mainLifts = exercises.filter { $0.exercise.isMainLiftOrVariation }
    let accessories = exercises.filter { $0.exercise.isAccessory }

    return [
      mainLifts.isEmpty
        ? nil
        : TodayWorkoutExerciseSection(kind: .mainLiftOrVariation, exercises: mainLifts),
      accessories.isEmpty
        ? nil
        : TodayWorkoutExerciseSection(kind: .accessory, exercises: accessories),
    ].compactMap(\.self)
  }
}
