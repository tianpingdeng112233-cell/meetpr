import CoreModels
import DesignSystem
import Foundation

struct TrainingHistoryVideoPresentation: Equatable, Sendable {
  let number: Int
  let video: CompletedSetVideo?

  /// Dense rows retain 44pt hit regions; overlap belongs to the closest icon.
  static func playbackNumber(at point: CGPoint, in regions: [Int: CGRect]) -> Int? {
    regions.filter { $0.value.contains(point) }.min { first, second in
      let firstDistance = abs(first.value.midY - point.y)
      let secondDistance = abs(second.value.midY - point.y)
      return firstDistance == secondDistance
        ? first.key < second.key : firstDistance < secondDistance
    }?.key
  }

  static func reservesVideoSpace(
    setLogIDs: [UUID?], videos: [StudentVideo], local: [VideoAttachment]
  ) -> Bool {
    let identifiers = Set(setLogIDs.compactMap { $0 })
    return videos.contains { $0.setLogID.map { identifiers.contains($0) } ?? false }
      || local.contains { identifiers.contains($0.setLogID) }
  }

  init(setLogID: UUID?, setIndex: Int, videos: [StudentVideo], local: [VideoAttachment]) {
    number = SetIndexDisplay.number(forZeroBasedIndex: setIndex)
    video = CompletedSetVideo.resolve(setLogID: setLogID, videos: videos, local: local)
  }
}
