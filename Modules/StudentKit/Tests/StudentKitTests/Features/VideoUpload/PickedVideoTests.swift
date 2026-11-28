import Foundation
import Testing

@testable import StudentKit

@Suite struct PickedVideoTests {
  private let ftyp = Data([0, 0, 0, 16] + Array("ftypisom".utf8) + [0, 0, 0, 0])
  private var complete: Data { ftyp + Data([0, 0, 0, 12] + Array("mdat".utf8) + [1, 2, 3, 4]) }

  @Test func reopensPhotosAfterShortReadAndKeepsOnlyTheCompleteCopy() async throws {
    var copies: [URL] = []
    defer { for url in copies { try? FileManager.default.removeItem(at: url) } }
    let picked = try await PickedVideo.load {
      let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
      copies.append(url)
      try (copies.count == 1 ? complete.dropLast() : complete).write(to: url)
      return PickedVideo(url: url)
    }
    #expect(copies.count == 2)
    let result = try #require(picked)
    #expect(try Data(contentsOf: result.url) == complete)
    #expect(!FileManager.default.fileExists(atPath: copies[0].path))
  }

  @Test func rejectsPersistentShortReadsAndPreservesTheOriginal() async throws {
    let original = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let short = complete.dropLast(2)
    try short.write(to: original)
    defer { try? FileManager.default.removeItem(at: original) }
    var copies: [URL] = []
    defer { for url in copies { try? FileManager.default.removeItem(at: url) } }
    await #expect(throws: AlbumVideoImportError.incomplete) {
      try await PickedVideo.load {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        copies.append(url)
        try FileManager.default.copyItem(at: original, to: url)
        return PickedVideo(url: url)
      }
    }
    #expect(copies.count == 2)
    #expect(copies.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    #expect(try Data(contentsOf: original) == short)
  }

  @Test func preservesCompleteOpenEndedAndUnknownContainersOnFirstRead() async throws {
    let openEnded = ftyp + Data([0, 0, 0, 0] + Array("mdat1234".utf8))
    let extended = ftyp + Data([0, 0, 0, 1] + Array("mdat".utf8) + [0, 0, 0, 0, 0, 0, 0, 16])
    for bytes in [complete, openEnded, extended, Data("other container".utf8)] {
      let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
      defer { try? FileManager.default.removeItem(at: url) }
      var reads = 0
      let result = try await PickedVideo.load {
        reads += 1
        try bytes.write(to: url)
        return PickedVideo(url: url)
      }
      #expect(result?.url == url)
      #expect(reads == 1)
      #expect(try Data(contentsOf: url) == bytes)
    }
  }

  @Test func cancellationDiscardsALateCopyWithoutReopeningPhotos() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let task = Task {
      try await PickedVideo.load {
        try complete.write(to: url)
        withUnsafeCurrentTask { $0?.cancel() }
        return PickedVideo(url: url)
      }
    }
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(!FileManager.default.fileExists(atPath: url.path))
  }
}
