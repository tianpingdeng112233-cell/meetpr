import CoreModels
import Testing

@testable import AppShell

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test(arguments: [UserRole.coachedStudent, .selfTrainStudent])
func evaluationAndTabStudentEntriesShareMigrationGate(role: UserRole) {
  #expect(RootView.authenticatedDestination(for: role) == .studentBehindE1RMGate)
}
