import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func demoCatalogKeepsBothLanguagesForPickerSearch() {
  let exercises = StudentDemoSeed.makePlanView().days.flatMap(\.exercises).map(\.exercise)
  let bench = exercises.first { $0.name == "窄握卧推" }
  #expect(bench?.nameEn == "Close Grip Bench Press")
  #expect(bench.map { StudentExerciseTag.all.matches($0, search: "close") } == true)
  #expect(bench.map { StudentExerciseTag.all.matches($0, search: "窄握") } == true)
}

@Test func studentPickerMapsEveryMuscleAndFamily() {
  for muscle in MuscleGroup.allCases {
    #expect(StudentExerciseTag.tag(for: muscle) != nil)
  }
  #expect(StudentExerciseTag.tag(for: .grip) == .forearms)
  #expect(StudentExerciseTag.tag(for: .hipFlexor) == .hips)
  #expect(StudentExerciseTag.tag(for: .tibialis) == .calves)
  #expect(StudentExerciseTag.tag(for: .mobility) == .other)
  #expect(StudentExerciseTag.tag(for: .cardio) == .other)
  #expect(StudentExerciseTag.rows.map(\.count) == [6, 7, 6])
}

@Test func studentPickerIncludesThreeFamiliesMultipleMusclesAndUnclassifiedExercises() {
  for family in LiftFamily.allCases {
    let exercise = Exercise(
      id: UUID(), name: "测试", nameEn: "Pause Lift", exerciseType: .mainLiftVariation,
      mainLiftFamily: family, isCompetitionLift: false,
      muscleGroups: [.back, .glute], equipment: [], createdAt: Date())
    let tags = StudentExerciseTag.tags(for: exercise)
    #expect(tags.contains(.back))
    #expect(tags.contains(.glutes))
    #expect(tags.contains(StudentExerciseTag(rawValue: family.rawValue) ?? .all))
    #expect(StudentExerciseTag.all.matches(exercise, search: "pause"))
    #expect(StudentExerciseTag.all.matches(exercise, search: "测试"))
  }
  let unknown = Exercise(
    id: UUID(), name: "Unknown", exerciseType: .accessory, isCompetitionLift: false,
    muscleGroups: [], equipment: [], createdAt: Date())
  #expect(StudentExerciseTag.tags(for: unknown) == [.all])
}
