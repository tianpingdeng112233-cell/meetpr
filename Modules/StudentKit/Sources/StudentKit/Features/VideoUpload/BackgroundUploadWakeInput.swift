import Foundation

struct BackgroundUploadWakeInput {
  let fileLocation: URL
  let chunker: VideoFileChunker
  let partCount: Int
}
