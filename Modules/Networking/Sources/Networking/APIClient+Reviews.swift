import Foundation

extension APIClient {
  public func submitSessionReview(
    date: String,
    _ request: SubmitSessionReviewRequestDTO,
    accessToken: String
  ) async throws -> SessionReviewDTO {
    try await put(
      path: "/students/me/reviews/\(date)", body: request, accessToken: accessToken)
  }

  public func studentSessionReviews(
    studentID: UUID,
    from: String,
    to: String,
    accessToken: String
  ) async throws -> SessionReviewsResponseDTO {
    try await get(
      path: "/students/\(studentID.uuidString)/reviews",
      queryItems: [
        URLQueryItem(name: "from", value: from),
        URLQueryItem(name: "to", value: to),
      ],
      accessToken: accessToken
    )
  }
}
