#if canImport(Darwin)
  import Darwin
  import Foundation

  struct CrashContext: Equatable, Sendable {
    let anonID: UUID
    let sessionID: UUID
    let screen: AnalyticsScreen
  }

  struct PendingCrash: Equatable, Sendable {
    let signalNumber: Int32
    let context: CrashContext
  }

  nonisolated(unsafe) private var analyticsCrashFD: Int32 = -1
  nonisolated(unsafe) private var analyticsCrashBuffer: UnsafeMutableRawPointer?
  private let analyticsCrashBufferLength = 116
  private let analyticsCrashBufferLock = NSLock()

  @_cdecl("meetpr_analytics_signal_handler")
  private func analyticsSignalHandler(_ signalNumber: Int32) {
    if analyticsCrashFD >= 0, let analyticsCrashBuffer {
      // The buffer and descriptor are prepared before handlers are installed.
      // The handler performs only a plain fixed-width memory store plus POSIX
      // async-signal-safe calls; no Foundation, allocation, lock, or encoding.
      analyticsCrashBuffer.advanced(by: 8).storeBytes(of: signalNumber, as: Int32.self)
      _ = Darwin.write(analyticsCrashFD, analyticsCrashBuffer, analyticsCrashBufferLength)
    }
    _ = Darwin.signal(signalNumber, SIG_DFL)
    _ = Darwin.raise(signalNumber)
    _exit(128 + signalNumber)
  }

  enum CrashCapture {
    private static let magic = Data("MPRCRSH1".utf8)
    private static let signalOffset = 8
    private static let anonIDOffset = 12
    private static let sessionIDOffset = 48
    private static let screenOffset = 84
    private static let screenLength = 32

    static func install(directory: URL, context: CrashContext) -> PendingCrash? {
      let fileURL = directory.appending(path: "pending-signal")
      let pending = readPendingCrash(from: fileURL)
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

      let descriptor = Darwin.open(fileURL.path, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR)
      guard descriptor >= 0 else { return pending }
      if analyticsCrashFD >= 0 {
        _ = Darwin.close(analyticsCrashFD)
      }
      analyticsCrashFD = descriptor
      if analyticsCrashBuffer == nil {
        analyticsCrashBuffer = UnsafeMutableRawPointer.allocate(
          byteCount: analyticsCrashBufferLength, alignment: MemoryLayout<Int32>.alignment)
      }
      updateContext(context)
      for signalNumber in [SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV, SIGTRAP] {
        Darwin.signal(signalNumber, analyticsSignalHandler)
      }
      return pending
    }

    static func updateContext(_ context: CrashContext) {
      let rendered = render(context: context)
      analyticsCrashBufferLock.withLock {
        guard let analyticsCrashBuffer else { return }
        rendered.withUnsafeBytes { source in
          guard let baseAddress = source.baseAddress else { return }
          analyticsCrashBuffer.copyMemory(
            from: baseAddress, byteCount: analyticsCrashBufferLength)
        }
      }
    }

    private static func render(context: CrashContext) -> Data {
      var data = Data(repeating: 0, count: analyticsCrashBufferLength)
      data.replaceSubrange(0..<magic.count, with: magic)
      write(context.anonID.uuidString.lowercased(), at: anonIDOffset, length: 36, to: &data)
      write(context.sessionID.uuidString.lowercased(), at: sessionIDOffset, length: 36, to: &data)
      write(context.screen.rawValue, at: screenOffset, length: screenLength, to: &data)
      return data
    }

    private static func write(_ value: String, at offset: Int, length: Int, to data: inout Data) {
      let bytes = value.utf8.prefix(length)
      data.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
    }

    private static func readPendingCrash(from fileURL: URL) -> PendingCrash? {
      guard let data = try? Data(contentsOf: fileURL), data.count == analyticsCrashBufferLength,
        data.prefix(magic.count) == magic
      else { return nil }
      let signalNumber = data.withUnsafeBytes {
        $0.loadUnaligned(fromByteOffset: signalOffset, as: Int32.self)
      }
      guard signalNumber > 0,
        let anonIDString = string(in: data, at: anonIDOffset, length: 36),
        let anonID = UUID(uuidString: anonIDString),
        let sessionIDString = string(in: data, at: sessionIDOffset, length: 36),
        let sessionID = UUID(uuidString: sessionIDString),
        let screenValue = string(in: data, at: screenOffset, length: screenLength),
        let screen = AnalyticsScreen(
          rawValue: screenValue)
      else { return nil }
      return PendingCrash(
        signalNumber: signalNumber,
        context: CrashContext(anonID: anonID, sessionID: sessionID, screen: screen))
    }

    private static func string(in data: Data, at offset: Int, length: Int) -> String? {
      let bytes = data[offset..<(offset + length)].prefix { $0 != 0 }
      return String(bytes: bytes, encoding: .utf8)
    }
  }
#else
  import Foundation

  struct CrashContext: Equatable, Sendable {
    let anonID: UUID
    let sessionID: UUID
    let screen: AnalyticsScreen
  }

  struct PendingCrash: Equatable, Sendable {
    let signalNumber: Int32
    let context: CrashContext
  }

  enum CrashCapture {
    static func install(directory: URL, context: CrashContext) -> PendingCrash? { nil }
    static func updateContext(_ context: CrashContext) {}
  }
#endif
