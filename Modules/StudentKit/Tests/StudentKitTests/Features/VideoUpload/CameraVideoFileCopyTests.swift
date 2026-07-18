import Foundation
import Testing

@testable import StudentKit

@Test("Camera video copy succeeds when the source exists")
func cameraVideoCopySucceedsWhenSourceExists() throws {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }

  let source = directory.appending(path: "capture.mov")
  let expectedData = Data("camera-video".utf8)
  try expectedData.write(to: source)

  let copied = try CameraVideoFileCopy.copyToTemporaryDirectory(
    sourceURL: source,
    temporaryDirectory: directory
  )

  #expect(copied != source)
  #expect(FileManager.default.fileExists(atPath: copied.path))
  #expect(try Data(contentsOf: copied) == expectedData)
}

@Test("Camera video copy throws when the source is missing")
func cameraVideoCopyThrowsWhenSourceIsMissing() throws {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }

  let missingSource = directory.appending(path: "missing.mov")

  #expect(throws: (any Error).self) {
    try CameraVideoFileCopy.copyToTemporaryDirectory(
      sourceURL: missingSource,
      temporaryDirectory: directory
    )
  }
}

@Test("Camera video copy preserves the source extension")
func cameraVideoCopyPreservesSourceExtension() throws {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }

  let source = directory.appending(path: "capture.MOV")
  try Data().write(to: source)

  let copied = try CameraVideoFileCopy.copyToTemporaryDirectory(
    sourceURL: source,
    temporaryDirectory: directory
  )

  #expect(copied.pathExtension == source.pathExtension)
}

@Test func handoffPicksTheCopiedURLOnSuccess() {
  let source = URL(fileURLWithPath: "/tmp/capture.MOV")
  let copied = URL(fileURLWithPath: "/tmp/copied.MOV")
  #expect(CameraCaptureHandoff.process(mediaURL: source, copy: { _ in copied }) == .picked(copied))
}

@Test func handoffFailsExactlyWhenMediaURLIsMissing() {
  #expect(CameraCaptureHandoff.process(mediaURL: nil, copy: { $0 }) == .failed)
}

@Test func handoffFailsWhenTheCopyThrows() {
  struct CopyError: Error {}
  let source = URL(fileURLWithPath: "/tmp/capture.MOV")
  let outcome = CameraCaptureHandoff.process(mediaURL: source, copy: { _ in throw CopyError() })
  #expect(outcome == .failed)
}
