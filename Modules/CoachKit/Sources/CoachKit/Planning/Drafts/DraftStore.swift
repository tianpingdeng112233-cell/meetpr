import Foundation
import SwiftData

@MainActor
public final class DraftStore {
  public let modelContainer: ModelContainer
  private let context: ModelContext

  public init(context: ModelContext) {
    self.modelContainer = context.container
    self.context = context
  }

  public init(modelContainer: ModelContainer) {
    self.modelContainer = modelContainer
    self.context = ModelContext(modelContainer)
  }

  public static let shared: DraftStore = {
    do {
      return try DraftStore(modelContainer: makeModelContainer(isStoredInMemoryOnly: false))
    } catch {
      fatalError("Unable to create persistent draft store: \(error)")
    }
  }()

  public static func inMemory() throws -> DraftStore {
    try DraftStore(modelContainer: makeModelContainer(isStoredInMemoryOnly: true))
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

  public func deleteAll() async throws {
    let drafts = try context.fetch(FetchDescriptor<DraftTrainingPlan>())
    for draft in drafts {
      context.delete(draft)
    }
    try context.save()
  }

  private static func makeModelContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
    let schema = Schema([
      DraftTrainingPlan.self,
      DraftPlanDay.self,
      DraftPlanExercise.self,
    ])
    let configuration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: isStoredInMemoryOnly
    )
    return try ModelContainer(for: schema, configurations: [configuration])
  }
}
