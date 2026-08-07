import Foundation

struct RestoredBackgroundRecord: Sendable {
  var tokens: Set<BackgroundUploadEventToken> = []
  var failure: VideoPartUploadFailure?
  var generation: Int?
}
