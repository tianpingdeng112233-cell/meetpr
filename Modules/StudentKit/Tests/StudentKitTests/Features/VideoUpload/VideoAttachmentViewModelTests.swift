import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func viewModelTracksUploadLifecycleThroughEvents() async throws {
  let harness = VideoUploadHarness()
  let viewModel = VideoAttachmentViewModel(
    manager: harness.manager,
    consentDefaults: makeDefaults()
  )
  let setLogID = UUID()
  let studentID = UUID()

  await viewModel.start(studentID: studentID)
  await viewModel.attach(
    sourceURL: harness.sourceURL, setLogID: setLogID, studentID: studentID)

  try await waitUntilOnMain {
    viewModel.rowStates[setLogID]?.attachment.status == .uploaded
  }
  #expect(viewModel.rowStates[setLogID]?.progress == 1)
  #expect(viewModel.lastErrorMessage == nil)
}

@MainActor
@Test func viewModelSurfacesDurationLimitError() async throws {
  let harness = VideoUploadHarness(exporter: MockVideoExporter(duration: 150))
  let viewModel = VideoAttachmentViewModel(
    manager: harness.manager,
    consentDefaults: makeDefaults()
  )
  let setLogID = UUID()

  await viewModel.attach(sourceURL: harness.sourceURL, setLogID: setLogID, studentID: UUID())

  #expect(viewModel.lastErrorMessage?.contains("120") == true)
  #expect(viewModel.rowStates[setLogID] == nil)
}

@MainActor
@Test func viewModelRemoveClearsRowState() async throws {
  let harness = VideoUploadHarness()
  let viewModel = VideoAttachmentViewModel(
    manager: harness.manager,
    consentDefaults: makeDefaults()
  )
  let setLogID = UUID()
  let studentID = UUID()

  await viewModel.start(studentID: studentID)
  await viewModel.attach(
    sourceURL: harness.sourceURL, setLogID: setLogID, studentID: studentID)
  try await waitUntilOnMain {
    viewModel.rowStates[setLogID]?.attachment.status == .uploaded
  }

  await viewModel.remove(setLogID: setLogID)
  try await waitUntilOnMain {
    viewModel.rowStates[setLogID] == nil
  }
}

@MainActor
@Test func viewModelConsentFlagPersistsToDefaults() throws {
  let defaults = makeDefaults()
  let harness = VideoUploadHarness()
  let viewModel = VideoAttachmentViewModel(manager: harness.manager, consentDefaults: defaults)

  #expect(!viewModel.hasConsented)
  viewModel.recordConsent()
  #expect(viewModel.hasConsented)
  #expect(defaults.bool(forKey: VideoAttachmentViewModel.consentDefaultsKey))
}

@MainActor
@Test func viewModelExposesUploadDurationLimitAndProcessingErrors() {
  let configuration = VideoUploadConfiguration(maxDurationSeconds: 75)
  let harness = VideoUploadHarness(configuration: configuration)
  let viewModel = VideoAttachmentViewModel(
    manager: harness.manager,
    consentDefaults: makeDefaults()
  )

  #expect(viewModel.maxDurationSeconds == 75)
  viewModel.reportVideoProcessingFailure()
  #expect(viewModel.lastErrorMessage == "视频处理失败,请重试")
}

@MainActor
@Test func viewModelSurfacesMissingLocalVideoWhenRetryCannotRecover() async throws {
  let harness = VideoUploadHarness()
  await harness.service.setDeterministicFailures([1: 1])
  let viewModel = VideoAttachmentViewModel(
    manager: harness.manager,
    consentDefaults: makeDefaults()
  )
  let setLogID = UUID()
  let studentID = UUID()
  await viewModel.start(studentID: studentID)
  await viewModel.attach(
    sourceURL: harness.sourceURL,
    setLogID: setLogID,
    studentID: studentID
  )
  try await waitUntilOnMain {
    viewModel.rowStates[setLogID]?.attachment.status == .failed
  }
  let attachment = try #require(viewModel.rowStates[setLogID]?.attachment)
  let exportedURL = await harness.manager.fileURL(for: attachment)
  try? FileManager.default.removeItem(at: exportedURL)
  if let sourceURL = await harness.manager.retainedSourceURL(recordID: attachment.id) {
    try? FileManager.default.removeItem(at: sourceURL)
  }

  await viewModel.retry(setLogID: setLogID)
  try await waitUntilOnMain {
    viewModel.missingAttachment != nil
  }

  #expect(viewModel.missingAttachment?.id == attachment.id)
  #expect(viewModel.lastErrorMessage == nil)
}

@MainActor
@Test func upgradeShowsLatestAttachmentInsteadOfOlderFailure() async throws {
  let harness = VideoUploadHarness()
  let studentID = UUID()
  let setID = UUID()
  let old = VideoAttachment(
    id: UUID(), setLogID: setID, studentID: studentID, status: .failed,
    contentType: "video/mp4", durationSeconds: 5, sizeBytes: 5,
    recordedAt: Date(timeIntervalSince1970: 1_794_000_000))
  let latest = VideoAttachment(
    id: UUID(), setLogID: setID, studentID: studentID, status: .uploaded,
    contentType: "video/mp4", durationSeconds: 5, sizeBytes: 5,
    recordedAt: old.recordedAt.addingTimeInterval(60))
  try await harness.repository.save(old)
  try await harness.repository.save(latest)
  let model = VideoAttachmentViewModel(manager: harness.manager, consentDefaults: makeDefaults())
  await model.start(studentID: studentID)
  #expect(model.rowStates[setID]?.attachment.id == latest.id)
  model.apply(.updated(old, progress: nil))
  #expect(model.rowStates[setID]?.attachment.id == latest.id)
}

@MainActor
private func makeDefaults() -> UserDefaults {
  let suiteName = "video-vm-tests-\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName) ?? .standard
  defaults.removePersistentDomain(forName: suiteName)
  return defaults
}
