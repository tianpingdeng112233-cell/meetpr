import Foundation
import SwiftData

@MainActor
public final class DraftStore {
  public let modelContainer: ModelContainer
  private let context: ModelContext
  private let stateDefaults: UserDefaults?
  private let stateNamespace: String

  public init(
    context: ModelContext,
    stateDefaults: UserDefaults? = .standard,
    stateNamespace: String = "meetpr.planning.draft"
  ) {
    self.modelContainer = context.container
    self.context = context
    self.stateDefaults = stateDefaults
    self.stateNamespace = stateNamespace
  }

  public init(
    modelContainer: ModelContainer,
    stateDefaults: UserDefaults? = .standard,
    stateNamespace: String = "meetpr.planning.draft"
  ) {
    self.modelContainer = modelContainer
    self.context = ModelContext(modelContainer)
    self.stateDefaults = stateDefaults
    self.stateNamespace = stateNamespace
  }

  public static let shared: DraftStore = {
    do {
      return try DraftStore(modelContainer: makeModelContainer(isStoredInMemoryOnly: false))
    } catch {
      fatalError("Unable to create persistent draft store: \(error)")
    }
  }()

  public static func inMemory(stateDefaults: UserDefaults? = nil) throws -> DraftStore {
    try DraftStore(
      modelContainer: makeModelContainer(isStoredInMemoryOnly: true),
      stateDefaults: stateDefaults
    )
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
    clearCurrentDayID(traineeID: traineeID)
    try context.save()
  }

  public func deleteAll() async throws {
    let drafts = try context.fetch(FetchDescriptor<DraftTrainingPlan>())
    for draft in drafts {
      context.delete(draft)
    }
    clearAllCurrentDayIDs()
    try context.save()
  }

  public func loadCurrentDayID(traineeID: UUID) -> UUID? {
    guard let rawValue = stateDefaults?.string(forKey: currentDayKey(traineeID: traineeID)) else {
      return nil
    }
    return UUID(uuidString: rawValue)
  }

  public func saveCurrentDayID(_ dayID: UUID?, traineeID: UUID) {
    guard let stateDefaults else { return }
    let key = currentDayKey(traineeID: traineeID)
    if let dayID {
      stateDefaults.set(dayID.uuidString, forKey: key)
    } else {
      stateDefaults.removeObject(forKey: key)
    }
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

  private func clearCurrentDayID(traineeID: UUID) {
    stateDefaults?.removeObject(forKey: currentDayKey(traineeID: traineeID))
  }

  private func clearAllCurrentDayIDs() {
    guard let stateDefaults else { return }
    let prefix = "\(stateNamespace).currentDay."
    for key in stateDefaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
      stateDefaults.removeObject(forKey: key)
    }
  }

  private func currentDayKey(traineeID: UUID) -> String {
    "\(stateNamespace).currentDay.\(traineeID.uuidString)"
  }
}
