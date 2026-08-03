import AVFoundation
import CoreMedia
import CryptoKit
import Foundation
import Testing

struct CompressedSampleFingerprint: Equatable {
  let payloadSHA256: Data
  let presentationTimeStamp: CMTime
  let decodeTimeStamp: CMTime
  let sampleCount: Int
}

func compressedSampleFingerprints(
  at url: URL,
  mediaType: AVMediaType
) async throws -> [CompressedSampleFingerprint] {
  let asset = AVURLAsset(url: url)
  let track = try #require(
    try await asset.loadTracks(withMediaType: mediaType).first
  )
  let reader = try AVAssetReader(asset: asset)
  let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
  output.alwaysCopiesSampleData = false
  guard reader.canAdd(output) else {
    throw FixtureError.unavailable("Unable to add compressed sample reader output")
  }
  reader.add(output)
  guard reader.startReading() else {
    throw FixtureError.unavailable(
      reader.error?.localizedDescription ?? "Compressed sample reader failed to start"
    )
  }

  var fingerprints: [CompressedSampleFingerprint] = []
  while let sampleBuffer = output.copyNextSampleBuffer() {
    let sampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
    guard sampleCount > 0 else { continue }
    let payload = try compressedPayload(of: sampleBuffer)
    fingerprints.append(
      CompressedSampleFingerprint(
        payloadSHA256: Data(SHA256.hash(data: payload)),
        presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
        decodeTimeStamp: CMSampleBufferGetDecodeTimeStamp(sampleBuffer),
        sampleCount: sampleCount
      )
    )
  }
  guard reader.status == .completed else {
    throw FixtureError.unavailable(
      reader.error?.localizedDescription ?? "Compressed sample reader did not complete"
    )
  }
  return normalizedSampleTimeline(fingerprints)
}

/// MOV and MP4 may express the same track with different constant edit-list
/// origins. Comparing every timestamp relative to the first media sample still
/// detects changed cadence, decode reordering, dropped, or inserted samples.
private func normalizedSampleTimeline(
  _ samples: [CompressedSampleFingerprint]
) -> [CompressedSampleFingerprint] {
  guard let first = samples.first else { return [] }
  return samples.map { sample in
    CompressedSampleFingerprint(
      payloadSHA256: sample.payloadSHA256,
      presentationTimeStamp: relativeTime(
        sample.presentationTimeStamp,
        origin: first.presentationTimeStamp
      ),
      decodeTimeStamp: relativeTime(
        sample.decodeTimeStamp,
        origin: first.decodeTimeStamp
      ),
      sampleCount: sample.sampleCount
    )
  }
}

private func relativeTime(_ time: CMTime, origin: CMTime) -> CMTime {
  guard time.isNumeric, origin.isNumeric else { return time }
  return CMTimeSubtract(time, origin)
}

private func compressedPayload(of sampleBuffer: CMSampleBuffer) throws -> Data {
  guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return Data() }
  let byteCount = CMBlockBufferGetDataLength(blockBuffer)
  guard byteCount > 0 else { return Data() }

  var payload = Data(count: byteCount)
  let copyStatus = payload.withUnsafeMutableBytes { bytes in
    guard let baseAddress = bytes.baseAddress else { return kCMBlockBufferBadPointerParameterErr }
    return CMBlockBufferCopyDataBytes(
      blockBuffer,
      atOffset: 0,
      dataLength: byteCount,
      destination: baseAddress
    )
  }
  guard copyStatus == kCMBlockBufferNoErr else {
    throw FixtureError.unavailable("Unable to copy compressed sample payload")
  }
  return payload
}
