import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct TodayWorkoutExerciseSectionTests {
  @Test func sectionsPutMainLiftsAndVariationsBeforeAccessoriesWithoutReordering() {
    let accessoryOne = planExercise(name: "划船", type: .accessory, sequenceIndex: 0)
    let variation = planExercise(name: "暂停深蹲", type: .mainLiftVariation, sequenceIndex: 1)
    let mainLift = planExercise(name: "卧推", type: .mainLift, sequenceIndex: 2)
    let accessoryTwo = planExercise(name: "下拉", type: .accessory, sequenceIndex: 3)

    let sections = TodayWorkoutExerciseSection.sections(
      for: [accessoryOne, variation, mainLift, accessoryTwo])

    #expect(sections.map(\.kind) == [.mainLiftOrVariation, .accessory])
    #expect(sections[0].exercises.map(\.exercise.name) == ["暂停深蹲", "卧推"])
    #expect(sections[1].exercises.map(\.exercise.name) == ["划船", "下拉"])
  }

  @Test func sectionsOmitEmptyKinds() {
    let mainLift = planExercise(name: "深蹲", type: .mainLift, sequenceIndex: 0)
    let accessory = planExercise(name: "划船", type: .accessory, sequenceIndex: 0)

    let mainOnly = TodayWorkoutExerciseSection.sections(for: [mainLift])
    let accessoryOnly = TodayWorkoutExerciseSection.sections(for: [accessory])

    #expect(mainOnly.map(\.kind) == [.mainLiftOrVariation])
    #expect(accessoryOnly.map(\.kind) == [.accessory])
    #expect(TodayWorkoutExerciseSection.sections(for: []).isEmpty)
  }

  @MainActor
  @Test func draftBuilderCarriesExerciseClassificationIntoPlateLoadingGate() throws {
    let accessory = planExercise(
      name: "绳索下压",
      type: .accessory,
      sequenceIndex: 0,
      prescribedSets: [prescribedSet()])
    let mainLift = planExercise(
      name: "硬拉",
      type: .mainLift,
      sequenceIndex: 1,
      prescribedSets: [prescribedSet()])

    let accessoryDraft = try #require(
      TodayWorkoutViewModel.makeDrafts(
        for: StudentPlanDay(id: UUID(), date: Date(), exercises: [accessory]),
        existingLogs: []
      ).first)
    let mainLiftDraft = try #require(
      TodayWorkoutViewModel.makeDrafts(
        for: StudentPlanDay(id: UUID(), date: Date(), exercises: [mainLift]),
        existingLogs: []
      ).first)

    #expect(accessoryDraft.isAccessory)
    #expect(!accessoryDraft.allowsPlateLoadingGuidance)
    #expect(!mainLiftDraft.isAccessory)
    #expect(mainLiftDraft.allowsPlateLoadingGuidance)
  }

  @Test func exerciseClassificationHelpersUseOnlyExerciseType() {
    let variation = exercise(name: "窄握卧推", type: .mainLiftVariation)
    let accessory = exercise(name: "哑铃卧推", type: .accessory)

    #expect(variation.isMainLiftOrVariation)
    #expect(!variation.isAccessory)
    #expect(!accessory.isMainLiftOrVariation)
    #expect(accessory.isAccessory)
  }

  private func planExercise(
    name: String,
    type: ExerciseType,
    sequenceIndex: Int,
    prescribedSets: [PrescribedSet] = []
  ) -> StudentPlanExercise {
    StudentPlanExercise(
      id: UUID(),
      exercise: exercise(name: name, type: type),
      sequenceIndex: sequenceIndex,
      prescribedSets: prescribedSets
    )
  }

  private func exercise(name: String, type: ExerciseType) -> Exercise {
    Exercise(
      id: UUID(),
      name: name,
      exerciseType: type,
      isCompetitionLift: type == .mainLift,
      muscleGroups: [],
      equipment: [],
      createdAt: Date()
    )
  }

  private func prescribedSet() -> PrescribedSet {
    PrescribedSet(id: UUID(), setIndex: 0, weightKg: 100, reps: 5, rpe: 8)
  }
}
