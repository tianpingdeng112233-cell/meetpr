import CoreModels
import Foundation

public struct ExercisesResponseDTO: Codable, Equatable, Sendable {
  public let exercises: [Exercise]

  public init(exercises: [Exercise]) {
    self.exercises = exercises
  }
}
