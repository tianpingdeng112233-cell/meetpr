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
private func makeDefaults() -> UserDefaults {
  let suiteName = "video-vm-tests-\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName) ?? .standard
  defaults.removePersistentDomain(forName: suiteName)
  return defaults
}
