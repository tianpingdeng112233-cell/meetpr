import CoreModels
import Foundation
import Networking

/// planExerciseID → LiftFamily across the trainee's whole published cycle.
/// The student-side projection only carries the current week (publish filters
/// by weekIndex), so growth points from other weeks would drop without this
/// (Codex review P1): the coach owns the full plan tree, so map from there.
public protocol CoachPlanFamilyMapProviding: Sendable {
  func familyMap(traineeID: UUID) async throws -> [UUID: LiftFamily]
}

public struct BackendCoachPlanFamilyMapProvider: CoachPlanFamilyMapProviding {
  let api: APIClient
  let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func familyMap(traineeID: UUID) async throws -> [UUID: LiftFamily] {
    let token = try await session.accessToken()
    let plans = try await api.studentPlans(
      studentID: traineeID,
      status: [.published],
      accessToken: token
    )
    guard
      let current = plans.plans.sorted(by: { $0.startDate > $1.startDate }).first
    else { return [:] }

    let tree = try await api.plan(id: current.id, accessToken: token)

    // exerciseID → family from the catalog (mains + variations carry one).
    async let mains = api.exercises(type: .mainLift, accessToken: token)
    async let variations = api.exercises(type: .mainLiftVariation, accessToken: token)
    let catalog = try await mains.exercises + variations.exercises
    let families = Dictionary(
      catalog.compactMap { exercise -> (UUID, LiftFamily)? in
        guard let family = exercise.mainLiftFamily else { return nil }
        return (exercise.id, family)
      },
      uniquingKeysWith: { first, _ in first }
    )

    var map: [UUID: LiftFamily] = [:]
    for day in tree.days {
      for exercise in day.exercises {
        if let family = families[exercise.exerciseID] {
          map[exercise.id] = family
        }
      }
    }
    return map
  }
}

/// Test/demo double: a fixed dictionary.
struct StaticCoachPlanFamilyMapProvider: CoachPlanFamilyMapProviding {
  let map: [UUID: LiftFamily]

  func familyMap(traineeID: UUID) async throws -> [UUID: LiftFamily] { map }
}
