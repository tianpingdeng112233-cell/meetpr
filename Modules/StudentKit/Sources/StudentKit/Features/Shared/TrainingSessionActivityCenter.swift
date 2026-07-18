import Observation
import RepositoryContracts

/// Shares the current gym-day session between the training and dashboard tabs.
@Observable
@MainActor
public final class TrainingSessionActivityCenter {
  public private(set) var snapshot: TrainingSessionSnapshot?
  private(set) var holdsOptimisticInProgress = false

  public init(snapshot: TrainingSessionSnapshot? = nil) {
    self.snapshot = snapshot
  }

  func storeOptimisticInProgress(_ snapshot: TrainingSessionSnapshot) {
    self.snapshot = snapshot
    holdsOptimisticInProgress = snapshot.session?.status == .inProgress
  }

  func storeAuthoritative(_ snapshot: TrainingSessionSnapshot?) {
    self.snapshot = snapshot
    holdsOptimisticInProgress = false
  }
}
