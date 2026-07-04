import CatalogKit
import CoreModels
import Foundation
import Testing

@available(iOS 17.0, macOS 14.0, *)
@Test func accessorySearchFoldsBarCharacterAcrossSpellings() {
  let ssb = makeExercise(name: "安全杆深蹲")  // written with 杆
  let highBar = makeExercise(name: "高杠位深蹲")  // written with 杠

  // 杆-typed query finds the 杠-spelled name…
  #expect(ExerciseSearch.matches(highBar, query: "高杆"))
  // …and 杠-typed query finds the 杆-spelled name.
  #expect(ExerciseSearch.matches(ssb, query: "安全杠深蹲"))
  // Exact spelling still matches.
  #expect(ExerciseSearch.matches(ssb, query: "安全杆"))
}

@available(iOS 17.0, macOS 14.0, *)
@Test func accessorySearchMatchesEnglishNameCaseInsensitively() {
  let sealRow = makeExercise(name: "海豹划船", nameEn: "Seal Row")

  #expect(ExerciseSearch.matches(sealRow, query: "seal"))
  #expect(!ExerciseSearch.matches(sealRow, query: "deadlift"))
}

@available(iOS 17.0, macOS 14.0, *)
private func makeExercise(name: String, nameEn: String? = nil) -> Exercise {
  Exercise(
    id: UUID(),
    name: name,
    nameEn: nameEn,
    exerciseType: .accessory,
    isCompetitionLift: false,
    muscleGroups: [.quad],
    equipment: [.barbell],
    createdAt: Date(timeIntervalSince1970: 0)
  )
}
