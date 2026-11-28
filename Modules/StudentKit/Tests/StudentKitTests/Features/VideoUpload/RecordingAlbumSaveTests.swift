import ChatUI
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Suite struct RecordingAlbumSaveTests {
  enum Scenario: CaseIterable {
    case badged, failedExport, cancelled, cancelledJob, expired, disabled, emptyBadge
    case failedPhoto, failedLink, backgroundTimeout
  }

  @Test(arguments: Scenario.allCases)
  func uploadOwnsOriginalWhileAlbumUsesItsOwnFile(_ scenario: Scenario) async throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let original = directory.appending(path: "original.mov")
    let output = directory.appending(path: "badged.mov")
    let raw = Data([1])
    let rendered = Data([2])
    try raw.write(to: original)
    var picked: [URL] = []
    let probe = AlbumProbe(scenario, original: original, output: output)
    let job = RecordingAlbumSave(
      backgroundGrace: .milliseconds(10), link: probe.link, export: probe.export, save: probe.save)
    let saving = job.use(
      original: original, badge: scenario == .emptyBadge ? .init() : .init(reps: 5),
      saveToAlbum: scenario != .disabled
    ) { url in
      picked.append(url)
      // Upload may consume its file as soon as the handoff returns.
      try? FileManager.default.removeItem(at: url)
    }
    #expect(picked == [original])
    if scenario == .expired { job.expire() }
    if scenario == .cancelledJob { saving?.cancel() }
    if scenario == .backgroundTimeout { job.enteredBackground() }
    try await saving?.value
    if scenario == .backgroundTimeout { #expect(probe.cancelledExport) }
    if scenario == .failedPhoto { #expect(probe.attempts == [rendered, raw]) }
    if scenario == .failedLink {
      #expect(probe.mapped == 1 && probe.exports == 0 && probe.attempts == [raw])
    }
    #expect(probe.photos == (scenario == .disabled ? [] : [scenario == .badged ? rendered : raw]))
    if scenario == .disabled || scenario == .emptyBadge { #expect(probe.exports == 0) }
    #expect(!FileManager.default.fileExists(atPath: output.path))
  }

  @MainActor private final class AlbumProbe {
    var photos: [Data] = []
    var attempts: [Data] = []
    var mapped = 0
    var cancelledExport = false
    var exportReturned = false
    var exports = 0
    let scenario: Scenario
    let original: URL
    let output: URL
    let raw = Data([1])
    let rendered = Data([2])

    init(_ scenario: Scenario, original: URL, output: URL) {
      self.scenario = scenario
      self.original = original
      self.output = output
    }

    func link(_ source: URL, _ link: URL) throws {
      if scenario == .failedLink { throw CocoaError(.fileWriteNoPermission) }
      try FileManager.default.linkItem(at: source, to: link)
    }
    func export(_ source: URL, _: VideoBadgeInfo) async throws -> URL {
      defer { exportReturned = true }
      exports += 1
      #expect(try Data(contentsOf: source) == raw)
      if scenario == .failedExport { throw CocoaError(.fileWriteUnknown) }
      if scenario == .cancelled { throw CancellationError() }
      if scenario == .backgroundTimeout {
        do {
          try await Task.sleep(for: .seconds(1))
        } catch {
          cancelledExport = true
          // AVFoundation can keep unwinding after cancellation.
          await Task { try? await Task.sleep(for: .milliseconds(100)) }.value
          throw error
        }
      }
      try rendered.write(to: output)
      return output
    }
    func save(_ source: RecordingAlbumSource) throws {
      let bytes: Data
      switch source {
      case .file(let url): bytes = try Data(contentsOf: url)
      case .mappedOriginal(let data, let filename):
        #expect(filename == original.lastPathComponent)
        mapped += 1
        bytes = data
      }
      if scenario == .backgroundTimeout { #expect(!exportReturned) }
      attempts.append(bytes)
      if scenario == .failedPhoto, bytes == rendered { throw CocoaError(.fileWriteUnknown) }
      photos.append(bytes)
    }
  }
}
