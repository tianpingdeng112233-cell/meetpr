import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

enum AlbumVideoImportError: Error { case incomplete }

/// File-URL transferable for PhotosPicker video items; the received file is
/// copied into tmp so it outlives the picker session.
struct PickedVideo: Identifiable, Transferable {
  let id = UUID()
  let url: URL

  static func load(from item: PhotosPickerItem) async throws -> Self? {
    try await load { try await item.loadTransferable(type: Self.self) }
  }

  static func load(copyFromPhotos: () async throws -> Self?) async throws -> Self? {
    for _ in 0..<2 {
      try Task.checkCancellation()
      guard let movie = try await copyFromPhotos() else { return nil }
      do {
        try Task.checkCancellation()
        if try !isIncomplete(movie.url) { return movie }
      } catch {
        try? FileManager.default.removeItem(at: movie.url)
        throw error
      }
      try FileManager.default.removeItem(at: movie.url)
    }
    throw AlbumVideoImportError.incomplete
  }

  // Inspect only top-level box headers. Unknown containers and open-ended boxes
  // continue through AVFoundation. A declared mdat beyond EOF proves a short copy.
  private static func isIncomplete(_ url: URL) throws -> Bool {
    let file = try FileHandle(forReadingFrom: url)
    defer { try? file.close() }
    let end = try file.seekToEnd()
    if end == 0 { return true }
    var offset: UInt64 = 0
    for _ in 0..<8192 {
      guard end - offset >= 8 else { return false }
      try file.seek(toOffset: offset)
      guard let header = try file.read(upToCount: 16), header.count >= 8 else { return false }
      let type = header[4..<8]
      if offset == 0, !type.elementsEqual("ftyp".utf8) { return false }
      let shortSize = header.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
      let size: UInt64
      if shortSize == 1 {
        guard header.count == 16 else { return type.elementsEqual("mdat".utf8) }
        size = header.withUnsafeBytes {
          $0.loadUnaligned(fromByteOffset: 8, as: UInt64.self).bigEndian
        }
      } else {
        size = UInt64(shortSize)
      }
      // Size zero is open-ended; undersized boxes are inconclusive.
      guard size >= (shortSize == 1 ? 16 : 8) else { return false }
      if size > end - offset { return type.elementsEqual("mdat".utf8) }
      offset += size
    }
    return false
  }

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(contentType: .movie) { movie in
      SentTransferredFile(movie.url)
    } importing: { received in
      let destination = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).\(received.file.pathExtension)")
      do {
        try FileManager.default.copyItem(at: received.file, to: destination)
      } catch {
        try? FileManager.default.removeItem(at: destination)
        throw error
      }
      return PickedVideo(url: destination)
    }
  }
}
