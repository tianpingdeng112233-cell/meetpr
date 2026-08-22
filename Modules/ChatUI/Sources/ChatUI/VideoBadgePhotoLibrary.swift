#if os(iOS)
  import Foundation
  import Photos

  enum VideoBadgePhotoLibrary {
    static func save(_ url: URL) async throws {
      let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
      let status =
        current == .notDetermined
        ? await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        : current
      guard status == .authorized || status == .limited else {
        throw VideoBadgePhotoLibraryError.permissionDenied
      }
      do {
        try await PHPhotoLibrary.shared().performChanges {
          PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
      } catch {
        throw VideoBadgePhotoLibraryError.saveFailed
      }
    }
  }

  enum VideoBadgePhotoLibraryError: Error, Equatable, Sendable {
    case permissionDenied
    case saveFailed
  }
#endif
