import Foundation
import SwiftData

@MainActor
public final class DraftStore {
  private let context: ModelContext

  public init(context: ModelContext) {
    self.context = context
  }

  public static func inMemory() throws -> DraftStore {
    let schema = Schema([
      DraftTrainingPlan.self,
      DraftPlanDay.self,
      DraftPlanExercise.self,
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return DraftStore(context: ModelContext(container))
  }

  public func loadDraft(traineeID: UUID) throws -> DraftTrainingPlan? {
    let drafts = try context.fetch(FetchDescriptor<DraftTrainingPlan>())
    return
      drafts
      .filter { $0.traineeID == traineeID }
      .sorted { $0.lastSavedAt > $1.lastSavedAt }
      .first
  }

  public func saveDraft(_ draft: DraftTrainingPlan) throws {
    draft.lastSavedAt = Date()
    if draft.modelContext == nil {
      context.insert(draft)
    }
    try context.save()
  }

  public func deleteDraft(traineeID: UUID) throws {
    let drafts = try context.fetch(FetchDescriptor<DraftTrainingPlan>())
      .filter { $0.traineeID == traineeID }
    for draft in drafts {
      context.delete(draft)
    }
    try context.save()
  }
}
