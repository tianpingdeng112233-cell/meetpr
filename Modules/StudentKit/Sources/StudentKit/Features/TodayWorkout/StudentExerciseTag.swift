import CoreModels
import Foundation

enum StudentExerciseTag: String, CaseIterable, Sendable {
  case all, squat, bench, deadlift, core, other
  case chest, back, shoulders, biceps, triceps, traps, forearms
  case quads, glutes, hamstrings, calves, adductors, hips

  static let rows: [[Self]] = [
    [.all, .squat, .bench, .deadlift, .core, .other],
    [.chest, .back, .shoulders, .biceps, .triceps, .traps, .forearms],
    [.quads, .glutes, .hamstrings, .calves, .adductors, .hips],
  ]

  static func tag(for muscle: MuscleGroup) -> Self? {
    muscleTags[muscle]
  }

  private static let muscleTags: [MuscleGroup: Self] = [
    .chest: .chest, .shoulder: .shoulders, .back: .back, .biceps: .biceps,
    .triceps: .triceps, .forearm: .forearms, .grip: .forearms, .core: .core,
    .quad: .quads, .hamstring: .hamstrings, .glute: .glutes,
    .hip: .hips, .hipFlexor: .hips, .adductor: .adductors,
    .calf: .calves, .tibialis: .calves, .trap: .traps,
    .mobility: .other, .cardio: .other,
  ]

  static func tags(for exercise: Exercise) -> Set<Self> {
    var tags = Set(exercise.muscleGroups.compactMap { tag(for: $0) })
    tags.insert(.all)
    if exercise.isMainLiftOrVariation, let family = exercise.mainLiftFamily,
      let tag = Self(rawValue: family.rawValue)
    {
      tags.insert(tag)
    }
    return tags
  }

  func matches(_ exercise: Exercise, search: String) -> Bool {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    return Self.tags(for: exercise).contains(self)
      && (query.isEmpty || exercise.name.localizedStandardContains(query)
        || exercise.nameEn?.localizedStandardContains(query) == true)
  }
}
