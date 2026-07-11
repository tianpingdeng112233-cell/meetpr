import CoreModels
import Foundation

extension APIClient {
  public func createPlan(
    _ request: CreatePlanRequestDTO,
    accessToken: String
  ) async throws -> PlanDTO {
    try await post(path: "/plans", body: request, accessToken: accessToken)
  }

  public func createPlanDay(
    planID: UUID,
    _ request: CreatePlanDayRequestDTO,
    accessToken: String
  ) async throws -> PlanDayDTO {
    try await post(
      path: "/plans/\(planID.uuidString)/days",
      body: request,
      accessToken: accessToken
    )
  }

  public func createPlanExercise(
    dayID: UUID,
    _ request: CreatePlanExerciseRequestDTO,
    accessToken: String
  ) async throws -> PlanExerciseDTO {
    try await post(
      path: "/plans/days/\(dayID.uuidString)/exercises",
      body: request,
      accessToken: accessToken
    )
  }

  public func createPlanSet(
    planExerciseID: UUID,
    _ request: CreatePlanSetRequestDTO,
    accessToken: String
  ) async throws -> PlanSetDTO {
    try await post(
      path: "/plans/exercises/\(planExerciseID.uuidString)/sets",
      body: request,
      accessToken: accessToken
    )
  }

  public func publishPlan(id: UUID, accessToken: String) async throws -> PlanDTO {
    try await post(path: "/plans/\(id.uuidString)/publish", accessToken: accessToken)
  }

  public func studentPlans(
    studentID: UUID,
    status: [PlanStatus] = [],
    accessToken: String
  ) async throws -> PlansResponseDTO {
    let queryItems =
      status.isEmpty
      ? []
      : [URLQueryItem(name: "status", value: status.map(\.rawValue).joined(separator: ","))]

    return try await get(
      path: "/students/\(studentID.uuidString)/plans",
      queryItems: queryItems,
      accessToken: accessToken
    )
  }

  public func plan(id: UUID, accessToken: String) async throws -> PlanWithChildrenDTO {
    try await get(path: "/plans/\(id.uuidString)", accessToken: accessToken)
  }

  public func shiftPlan(id: UUID, accessToken: String) async throws -> PlanShiftDTO {
    try await post(path: "/plans/\(id.uuidString)/shift", accessToken: accessToken)
  }

  public func cancelPlanShift(id: UUID, accessToken: String) async throws {
    try await deleteNoContent(
      path: "/plans/\(id.uuidString)/shift",
      accessToken: accessToken
    )
  }
}
