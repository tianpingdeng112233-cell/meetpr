import Foundation

extension APIClient {
  public func bodyWeights(accessToken: String) async throws -> BodyWeightRecordsDTO {
    try await get(path: "/students/me/body-weights", accessToken: accessToken)
  }

  public func deleteBodyWeight(on date: String, accessToken: String) async throws
    -> BodyWeightDeleteDTO
  {
    try await delete(path: "/students/me/body-weights/\(date)", accessToken: accessToken)
  }

  public func saveBodyWeight(
    on date: String, kilograms: Decimal, accessToken: String
  ) async throws -> BodyWeightWriteDTO {
    try await put(
      path: "/students/me/body-weights/\(date)",
      body: BodyWeightInputDTO(
        weightKg: kilograms.formatted(
          .number.locale(Locale(identifier: "en_US_POSIX"))
            .precision(.fractionLength(2)).grouping(.never))),
      accessToken: accessToken)
  }
}

private struct BodyWeightInputDTO: Encodable {
  let weightKg: String
}
