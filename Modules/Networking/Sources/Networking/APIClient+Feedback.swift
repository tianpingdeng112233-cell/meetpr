import Foundation

extension APIClient {
  public func createFeedback(
    _ request: CreateFeedbackRequestDTO,
    accessToken: String
  ) async throws -> FeedbackDTO {
    try await post(path: "/coach/feedback", body: request, accessToken: accessToken)
  }

  public func studentFeedback(
    studentID: UUID,
    accessToken: String
  ) async throws -> FeedbackItemsResponseDTO {
    try await get(path: "/students/\(studentID.uuidString)/feedback", accessToken: accessToken)
  }

  public func markFeedbackRead(id: UUID, accessToken: String) async throws {
    try await patchNoContent(path: "/feedback/\(id.uuidString)/read", accessToken: accessToken)
  }
}
