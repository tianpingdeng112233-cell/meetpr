import CoreModels
import Foundation

extension APIClient {
  public func createPlan(
    _ request: CreatePlanRequestDTO,
    accessToken: String
  ) async throws -> PlanDTO {
    try await post(path: "/plans", body: request, accessToken: accessToken)
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
}
