import CoreModels
import Foundation

extension APIClient {
  public func weightSuggestions(
    studentID: UUID, dayID: UUID, accessToken: String
  ) async throws -> [SetWeightSuggestionRecord] {
    let response: WeightSuggestionsResponse = try await get(
      path: "/students/\(studentID.uuidString)/plan-days/\(dayID.uuidString)/weight-suggestions",
      accessToken: accessToken)
    return response.suggestions
  }
}

private struct WeightSuggestionsResponse: Decodable {
  let suggestions: [SetWeightSuggestionRecord]
}
