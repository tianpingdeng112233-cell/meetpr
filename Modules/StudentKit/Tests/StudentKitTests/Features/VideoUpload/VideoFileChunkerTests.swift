import Foundation
import Testing

@testable import StudentKit

private let fiveMB = 5 * 1024 * 1024

@Test func chunkerCountsExactMultipleWithoutTrailingEmptyPart() throws {
  let chunker = VideoFileChunker(partSizeBytes: fiveMB)
  // Exactly 5 MB → one part, not one part plus an empty one.
  #expect(try chunker.partCount(totalBytes: Int64(fiveMB)) == 1)
  #expect(try chunker.partCount(totalBytes: Int64(fiveMB) * 3) == 3)
}

@Test func chunkerAddsPartForRemainder() throws {
  let chunker = VideoFileChunker(partSizeBytes: fiveMB)
  #expect(try chunker.partCount(totalBytes: Int64(fiveMB) + 1) == 2)
  // Spec sizing note: 15 MB (120s at ~1Mbps) → 3 parts.
  #expect(try chunker.partCount(totalBytes: 15 * 1024 * 1024) == 3)
}

@Test func chunkerHandlesFileSmallerThanOnePart() throws {
  let chunker = VideoFileChunker(partSizeBytes: fiveMB)
  #expect(try chunker.partCount(totalBytes: 100) == 1)
}

@Test func chunkerRejectsEmptyFile() {
  let chunker = VideoFileChunker(partSizeBytes: fiveMB)
  #expect(throws: VideoUploadError.emptyFile) {
    try chunker.partCount(totalBytes: 0)
  }
}

@Test func chunkerReadsExactByteSlices() throws {
  // 2.5 parts of 4 bytes: parts are [0,1,2,3] [4,5,6,7] [8,9].
  let bytes = Data((0..<10).map { UInt8($0) })
  let fileURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("chunker-test-\(UUID().uuidString).bin")
  try bytes.write(to: fileURL)
  defer { try? FileManager.default.removeItem(at: fileURL) }

  let chunker = VideoFileChunker(partSizeBytes: 4)
  #expect(try chunker.partCount(totalBytes: 10) == 3)
  #expect(try chunker.readPart(partNumber: 1, from: fileURL) == bytes[0..<4])
  #expect(try chunker.readPart(partNumber: 2, from: fileURL) == bytes[4..<8])
  #expect(try chunker.readPart(partNumber: 3, from: fileURL) == bytes[8..<10])
}

@Test func chunkerThrowsWhenReadingPastTheEnd() throws {
  let fileURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("chunker-test-\(UUID().uuidString).bin")
  try Data([1, 2, 3]).write(to: fileURL)
  defer { try? FileManager.default.removeItem(at: fileURL) }

  let chunker = VideoFileChunker(partSizeBytes: 4)
  #expect(throws: VideoUploadError.fileUnreadable) {
    _ = try chunker.readPart(partNumber: 2, from: fileURL)
  }
}

@Test func chunkerFilePartsMatchInMemorySlicesByteForByte() throws {
  let bytes = Data((0..<23).map { UInt8($0) })
  let root = FileManager.default.temporaryDirectory
    .appending(path: "chunk-file-test-\(UUID().uuidString)", directoryHint: .isDirectory)
  let source = root.appending(path: "source.bin")
  let parts = root.appending(path: "source.parts", directoryHint: .isDirectory)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  try bytes.write(to: source)
  defer { try? FileManager.default.removeItem(at: root) }

  let chunker = VideoFileChunker(partSizeBytes: 5)
  let fileParts = try chunker.writeParts(from: source, to: parts)

  #expect(fileParts.count == 5)
  for (index, partURL) in fileParts.enumerated() {
    #expect(try Data(contentsOf: partURL) == chunker.readPart(partNumber: index + 1, from: source))
  }
}
