#if DEBUG
  import Foundation

  @MainActor
  enum PlanningPreviewFactory {
    static func makeStore() -> DraftStore {
      do {
        return try DraftStore.inMemory()
      } catch {
        fatalError("Unable to create in-memory draft store for preview: \(error)")
      }
    }
  }
#endif
