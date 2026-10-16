import CoreModels
import Foundation
import Testing

@testable import StudentKit

/// `MainLiftExerciseFamilyResolver.families(in:)` — the week-grid SBD badge
/// classifier. Main lifts AND variations count toward their family; accessories
/// never do; output is deduped and ordered S→B→D.
@Suite struct SBDWeekBadgeTests {
  @Test func singleMainLiftReturnsItsFamily() {
    let dayPlan = day([exercise("深蹲", .mainLift, .squat)])
    #expect(MainLiftExerciseFamilyResolver.families(in: dayPlan) == [.squat])
  }

  @Test func variationCountsTowardItsFamily() {
    let dayPlan = day([exercise("暂停深蹲", .mainLiftVariation, .squat)])
    #expect(MainLiftExerciseFamilyResolver.families(in: dayPlan) == [.squat])
  }

  @Test func mainLiftAndVariationOfSameFamilyDedupe() {
    let dayPlan = day([
      exercise("深蹲", .mainLift, .squat),
      exercise("暂停深蹲", .mainLiftVariation, .squat),
    ])
    #expect(MainLiftExerciseFamilyResolver.families(in: dayPlan) == [.squat])
  }

  @Test func squatPlusBenchOrdersSBeforeB() {
    let dayPlan = day([
      exercise("深蹲", .mainLift, .squat),
      exercise("卧推", .mainLift, .bench),
    ])
    #expect(MainLiftExerciseFamilyResolver.families(in: dayPlan) == [.squat, .bench])
  }

  @Test func orderIsAlwaysSBDRegardlessOfInputOrder() {
    let dayPlan = day([
      exercise("硬拉", .mainLift, .deadlift),
      exercise("卧推", .mainLift, .bench),
      exercise("深蹲", .mainLift, .squat),
    ])
    #expect(MainLiftExerciseFamilyResolver.families(in: dayPlan) == [.squat, .bench, .deadlift])
  }

  @Test func benchPlusDeadliftReadsBD() {
    let dayPlan = day([
      exercise("卧推", .mainLift, .bench),
      exercise("硬拉", .mainLift, .deadlift),
    ])
    #expect(MainLiftExerciseFamilyResolver.families(in: dayPlan) == [.bench, .deadlift])
  }

  @Test func accessoriesNeverContribute() {
    // family == nil on accessories — no inference from movement pattern.
    let dayPlan = day([
      exercise("坐姿划船", .accessory, nil),
      exercise("腿屈伸", .accessory, nil),
    ])
    #expect(MainLiftExerciseFamilyResolver.families(in: dayPlan).isEmpty)
  }

  @Test func mixedMainAndAccessoryKeepsOnlyMain() {
    let dayPlan = day([
      exercise("窄握卧推", .mainLiftVariation, .bench),
      exercise("坐姿划船", .accessory, nil),
    ])
    #expect(MainLiftExerciseFamilyResolver.families(in: dayPlan) == [.bench])
  }

  @Test func emptyDayReturnsEmpty() {
    #expect(MainLiftExerciseFamilyResolver.families(in: day([])).isEmpty)
  }

  @Test func sharedDayNameCoversEverySBDCombination() {
    let cases: [([StudentPlanExercise], String)] = [
      ([exercise("深蹲", .mainLift, .squat)], "S 日"),
      ([exercise("卧推", .mainLift, .bench)], "B 日"),
      ([exercise("硬拉", .mainLift, .deadlift)], "D 日"),
      (
        [
          exercise("深蹲", .mainLift, .squat),
          exercise("卧推", .mainLift, .bench),
        ],
        "SB 日"
      ),
      (
        [
          exercise("深蹲", .mainLift, .squat),
          exercise("硬拉", .mainLift, .deadlift),
        ],
        "SD 日"
      ),
      (
        [
          exercise("卧推", .mainLift, .bench),
          exercise("硬拉", .mainLift, .deadlift),
        ],
        "BD 日"
      ),
      (
        [
          exercise("硬拉", .mainLift, .deadlift),
          exercise("深蹲", .mainLift, .squat),
          exercise("卧推", .mainLift, .bench),
        ],
        "SBD 日"
      ),
      ([exercise("划船", .accessory, nil)], "辅助日"),
    ]

    for (exercises, expected) in cases {
      #expect(MainLiftExerciseFamilyResolver.dayName(in: day(exercises)) == expected)
    }
  }

  @Test func sharedDayNameDistinguishesNoPlan() {
    #expect(MainLiftExerciseFamilyResolver.dayName(in: nil) == nil)
  }
}

// MARK: - Builders

private func day(_ exercises: [StudentPlanExercise]) -> StudentPlanDay {
  StudentPlanDay(id: UUID(), date: Date(timeIntervalSince1970: 0), exercises: exercises)
}

private func exercise(
  _ name: String,
  _ type: ExerciseType,
  _ family: LiftFamily?
) -> StudentPlanExercise {
  StudentPlanExercise(
    id: UUID(),
    exercise: Exercise(
      id: UUID(),
      name: name,
      exerciseType: type,
      mainLiftFamily: family,
      isCompetitionLift: type == .mainLift,
      muscleGroups: [],
      equipment: [],
      movementPattern: [],
      createdAt: Date(timeIntervalSince1970: 0)
    ),
    sequenceIndex: 0,
    prescribedSets: []
  )
}
