import CoreModels
import Foundation
import Testing
import UserNotifications

@testable import StudentKit

@Test func uploadNotificationRequestsNormalAuthorizationAndUsesAggregateCopy() {
  #expect(UploadFailureNotifier.authorizationOptions == [.alert, .sound, .badge])
  #expect(UploadFailureNotifier.shouldRequestAuthorization(status: .notDetermined))
  #expect(!UploadFailureNotifier.shouldRequestAuthorization(status: .authorized))
  #expect(!UploadFailureNotifier.shouldRequestAuthorization(status: .denied))
  #expect(UploadFailureNotifier.shouldRequestAuthorization(status: .provisional))
  let destination = UploadFailureDestination(
    setLogID: UUID(), trainingDate: Date(timeIntervalSince1970: 1_794_000_000))
  let content = UploadFailureNotifier.content(count: 2, destination: destination)
  #expect(content.body == "有 2 条训练视频没传上，点击重试")
  #expect(content.sound != nil)
  #expect(UploadFailureDestination(notificationUserInfo: content.userInfo) == destination)
}

@Test func recoveryChecksNormalAuthorizationOnceForExistingUploads() async throws {
  let notifier = RecordingUploadFailureNotifier()
  let harness = VideoUploadHarness(failureNotifier: notifier)
  let studentID = UUID()
  try await harness.repository.save(
    VideoAttachment(
      id: UUID(), setLogID: UUID(), studentID: studentID, status: .failed,
      contentType: "video/mp4", durationSeconds: 5, sizeBytes: 5, recordedAt: Date()))
  await harness.manager.recoverInterruptedUploads(studentID: studentID)
  await harness.manager.recoverInterruptedUploads(studentID: studentID)
  #expect(await notifier.authorizationRequestCount == 1)
}
