import Foundation
import SwiftData

@Model
public final class DraftPlanExercise {
  public var id: UUID = UUID()
  public var exerciseID: UUID = UUID()
  public var isMainLift: Bool = true
  public var sortOrder: Int = 0
  public var notes: String?
  public var setsData: Data?
  public var day: DraftPlanDay?

  public init(
    id: UUID = UUID(),
    exerciseID: UUID,
    isMainLift: Bool = true,
    sortOrder: Int,
    notes: String? = nil,
    setsData: Data? = nil,
    day: DraftPlanDay? = nil
  ) {
    self.id = id
    self.exerciseID = exerciseID
    self.isMainLift = isMainLift
    self.sortOrder = sortOrder
    self.notes = notes
    self.setsData = setsData
    self.day = day
  }
}
