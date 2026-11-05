import CoreModels
import Foundation
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Test func restoringDayVideoDoesNotPromptForAnotherDaysMissingFile() async throws {
  let harness = VideoUploadHarness()
  defer { try? FileManager.default.removeItem(at: harness.filesDirectory) }
  let studentID = UUID()
  let date = Date(timeIntervalSince1970: 1_794_000_000)
  let history = VideoAttachment(
    id: UUID(), setLogID: UUID(), studentID: studentID, status: .failed,
    contentType: "video/mp4", durationSeconds: 10, sizeBytes: 100,
    localFileName: "missing-history.mp4", recordedAt: date.addingTimeInterval(-86_400),
    trainingDate: date.addingTimeInterval(-86_400))
  try await harness.repository.save(history)
  let view = TodayWorkoutView(
    studentID: studentID, date: date,
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore()),
    logs: InMemoryStudentTrainingLogRepository(),
    videoUploads: VideoUploadServices(manager: harness.manager))
  let host = try view.inspect().navigationStack().modifier(VideoMissingFileHost.self).actualView()

  await host.onRestored()

  #expect(host.model.missingAttachment == nil)
  #expect(try await harness.repository.fetch(id: history.id)?.status == .failed)

  let sameDay = VideoAttachment(
    id: UUID(), setLogID: UUID(), studentID: studentID, status: .failed,
    contentType: "video/mp4", durationSeconds: 10, sizeBytes: 100,
    localFileName: "missing-current.mp4", recordedAt: date, trainingDate: date)
  try await harness.repository.save(sameDay)

  await host.onRestored()

  #expect(host.model.missingAttachment?.id == sameDay.id)
}
