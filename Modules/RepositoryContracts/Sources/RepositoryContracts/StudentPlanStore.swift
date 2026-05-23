import CoreModels
import Foundation

/// Shared bridge between the coach publish path (writes the projection) and the
/// student read path (reads it).
///
/// The concrete in-memory implementation lives in AppShell and is injected at the
/// composition root. Both the coach-side and student-side repositories depend only
/// on this protocol, which keeps CoachKit ⊥ StudentKit and stops either feature
/// module from importing AppShell.
public protocol StudentPlanStore: Sendable {
  func savePublishedProjection(_ projection: StudentPlanView, forStudent studentID: UUID) async
  func getPublishedProjection(forStudent studentID: UUID) async -> StudentPlanView?
}
