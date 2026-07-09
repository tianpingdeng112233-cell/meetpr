import Foundation

/// Private, non-user-visible storage for locally cached health/training data.
///
/// Earlier builds placed these files under Documents, which makes them
/// user-visible and eligible for normal document backup. Keep them in
/// Application Support instead, migrate the old location once, and apply the
/// strongest practical iOS file protection after each write.
enum SecureLocalStorage {
  static func directory(relativePath: String, fileManager: FileManager = .default) -> URL {
    let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let applicationSupport =
      fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("MeetPR", isDirectory: true)
    let destination =
      relativePath
      .split(separator: "/")
      .reduce(applicationSupport) { partial, component in
        partial.appendingPathComponent(String(component), isDirectory: true)
      }
    let legacy =
      relativePath
      .split(separator: "/")
      .reduce(documents) { partial, component in
        partial.appendingPathComponent(String(component), isDirectory: true)
      }

    if !fileManager.fileExists(atPath: destination.path),
      fileManager.fileExists(atPath: legacy.path)
    {
      do {
        try fileManager.createDirectory(
          at: destination.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        try fileManager.moveItem(at: legacy, to: destination)
      } catch {
        // Falling back to the old directory is safer than treating existing
        // data as empty if a migration is interrupted or storage is full.
        harden(legacy, fileManager: fileManager)
        return legacy
      }
    }

    do {
      try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
      harden(destination, fileManager: fileManager)
      return destination
    } catch {
      // The old Documents location remains a last-resort compatibility path.
      harden(legacy, fileManager: fileManager)
      return legacy
    }
  }

  static func harden(_ url: URL, fileManager: FileManager = .default) {
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var mutableURL = url
    try? mutableURL.setResourceValues(values)

    #if os(iOS)
      try? fileManager.setAttributes(
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
        ofItemAtPath: url.path
      )
    #endif
  }
}
