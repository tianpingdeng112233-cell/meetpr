import CoreModels
import Foundation

/// Resolves squat/bench/deadlift families from the current plan's main-lift
/// slots. V0.1: the exercise→family map is plan-derived (not a static catalog;
/// variation curves are V0.1.x). Shared by the growth curve and the dashboard
/// e1RM trend card so the two never drift.
enum MainLiftExerciseFamilyResolver {
  static let dashboardFamilies: [LiftFamily] = [.squat, .bench, .deadlift]

  static func exerciseIDsByFamily(
    in plan: StudentPlanView?,
    onboarding: OnboardingProfile?
  ) -> [LiftFamily: Set<UUID>] {
    var idsByFamily: [LiftFamily: Set<UUID>] = [:]
    for day in plan?.days ?? [] {
      for slot in day.exercises {
        let exercise = slot.exercise
        guard let family = resolveCompetitionFamily(exercise: exercise, onboarding: onboarding)
        else {
          continue
        }
        idsByFamily[family, default: []].insert(exercise.id)
      }
    }
    return idsByFamily
  }

  static func family(
    for exerciseID: UUID,
    in idsByFamily: [LiftFamily: Set<UUID>]
  ) -> LiftFamily? {
    idsByFamily.first { $0.value.contains(exerciseID) }?.key
  }

  /// Catalog bucketing for planless (solo) students — comp lifts only, same
  /// rule as the plan path: variations carry different leverages and would
  /// pollute the trend line (variation curves are V0.1.x).
  static func exerciseIDsByFamily(
    catalog: [Exercise],
    onboarding: OnboardingProfile?
  ) -> [LiftFamily: Set<UUID>] {
    var idsByFamily: [LiftFamily: Set<UUID>] = [:]
    for exercise in catalog {
      guard let family = resolveCompetitionFamily(exercise: exercise, onboarding: onboarding)
      else {
        continue
      }
      idsByFamily[family, default: []].insert(exercise.id)
    }
    return idsByFamily
  }

  /// Union of the plan and catalog universes (spec 047 §1): coached keeps its
  /// plan tree (custom exercises included), solo brings the bundled catalog.
  static func exerciseIDsByFamily(
    in plan: StudentPlanView?,
    catalog: [Exercise],
    onboarding: OnboardingProfile?
  ) -> [LiftFamily: Set<UUID>] {
    let planBuckets = exerciseIDsByFamily(in: plan, onboarding: onboarding)
    guard !catalog.isEmpty else { return planBuckets }
    return planBuckets.merging(
      exerciseIDsByFamily(catalog: catalog, onboarding: onboarding)
    ) { $0.union($1) }
  }

  /// Recorder-side family map. It uses the same per-student competition gate
  /// as chart bucketing so a variation can never create a hidden e1RM point.
  static func recorderFamilies(
    catalog: [Exercise],
    onboarding: OnboardingProfile?
  ) -> [UUID: LiftFamily] {
    Dictionary(
      catalog.compactMap { exercise in
        resolveCompetitionFamily(exercise: exercise, onboarding: onboarding)
          .map { (exercise.id, $0) }
      },
      uniquingKeysWith: { first, _ in first })
  }

  /// Every squat/bench/deadlift family trained on one day — main lifts **and**
  /// their variations (暂停深蹲 / 窄握卧推 等变式计入对应家族;辅助动作不计,
  /// 它们没有 `mainLiftFamily`)。去重后按 S→B→D 固定顺序返回,驱动仪表盘周历
  /// 的多字母角标(深蹲+卧推日 → `[.squat, .bench]` → "SB")。
  static func families(in day: StudentPlanDay) -> [LiftFamily] {
    var present: Set<LiftFamily> = []
    for slot in day.exercises {
      let exercise = slot.exercise
      guard
        exercise.exerciseType == .mainLift || exercise.exerciseType == .mainLiftVariation,
        let family = exercise.mainLiftFamily
      else { continue }
      present.insert(family)
    }
    return dashboardFamilies.filter(present.contains)
  }
}

extension LiftFamily {
  var studentDisplayName: String {
    switch self {
    case .squat: "深蹲"
    case .bench: "卧推"
    case .deadlift: "硬拉"
    }
  }
}
