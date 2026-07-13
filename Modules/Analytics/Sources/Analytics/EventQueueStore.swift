import Foundation

public actor EventQueueStore {
  public static let defaultCapacity = 1_000
  public static let defaultTTL: TimeInterval = 7 * 24 * 60 * 60

  private let fileURL: URL
  private let capacity: Int
  private let ttl: TimeInterval
  private let now: @Sendable () -> Date
  private var queue = PersistedAnalyticsQueue()
  private var hasLoaded = false

  public init(
    directory: URL? = nil,
    capacity: Int = defaultCapacity,
    ttl: TimeInterval = defaultTTL,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    let root = directory ?? URL.documentsDirectory.appending(path: "analytics/queue")
    fileURL = root.appending(path: "events.json")
    self.capacity = max(0, capacity)
    self.ttl = ttl
    self.now = now
  }

  func enqueue(_ event: AnalyticsEnvelope) {
    loadIfNeeded()
    pruneExpired()
    queue.events.append(event)
    enforceCapacity()
    persist()
  }

  func enqueue(_ payload: FrictionFeedbackPayload) {
    loadIfNeeded()
    pruneExpired()
    queue.feedback.append(payload)
    enforceCapacity()
    persist()
  }

  func events(limit: Int = 50, excluding excludedIDs: Set<UUID> = []) -> [AnalyticsEnvelope] {
    loadIfNeeded()
    pruneExpiredAndPersistIfNeeded()
    return Array(queue.events.lazy.filter { !excludedIDs.contains($0.id) }.prefix(max(0, limit)))
  }

  func feedback() -> [FrictionFeedbackPayload] {
    loadIfNeeded()
    pruneExpiredAndPersistIfNeeded()
    return queue.feedback
  }

  func removeEvents(ids: Set<UUID>) {
    loadIfNeeded()
    queue.events.removeAll { ids.contains($0.id) }
    persist()
  }

  func moveEventsToBack(ids: Set<UUID>) {
    loadIfNeeded()
    let moved = queue.events.filter { ids.contains($0.id) }
    guard !moved.isEmpty else { return }
    queue.events.removeAll { ids.contains($0.id) }
    queue.events.append(contentsOf: moved)
    persist()
  }

  func removeFeedback(id: UUID) {
    loadIfNeeded()
    queue.feedback.removeAll { $0.id == id }
    persist()
  }

  func replaceFeedback(_ payload: FrictionFeedbackPayload) {
    loadIfNeeded()
    guard let index = queue.feedback.firstIndex(where: { $0.id == payload.id }) else { return }
    queue.feedback[index] = payload
    persist()
  }

  func removeAll() {
    hasLoaded = true
    queue = PersistedAnalyticsQueue()
    persist()
  }

  func count() -> Int {
    loadIfNeeded()
    pruneExpiredAndPersistIfNeeded()
    return queue.events.count + queue.feedback.count
  }

  private func pruneExpiredAndPersistIfNeeded() {
    let previousCount = queue.events.count + queue.feedback.count
    pruneExpired()
    if previousCount != queue.events.count + queue.feedback.count {
      persist()
    }
  }

  private func loadIfNeeded() {
    guard !hasLoaded else { return }
    queue = Self.load(from: fileURL, now: now(), ttl: ttl)
    hasLoaded = true
  }

  private func pruneExpired() {
    let cutoff = now().addingTimeInterval(-ttl)
    queue.events.removeAll { $0.timestamp < cutoff }
    queue.feedback.removeAll { $0.timestamp < cutoff }
  }

  private func enforceCapacity() {
    while queue.events.count + queue.feedback.count > capacity {
      let eventDate = queue.events.first?.timestamp ?? .distantFuture
      let feedbackDate = queue.feedback.first?.timestamp ?? .distantFuture
      if eventDate <= feedbackDate {
        if !queue.events.isEmpty { queue.events.removeFirst() }
      } else if !queue.feedback.isEmpty {
        queue.feedback.removeFirst()
      }
    }
  }

  private func persist() {
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      let data = try Self.encoder.encode(queue)
      try data.write(to: fileURL, options: .atomic)
    } catch {
      // Analytics must never affect the feature that emitted it.
    }
  }

  private static func load(from fileURL: URL, now: Date, ttl: TimeInterval)
    -> PersistedAnalyticsQueue
  {
    guard let data = try? Data(contentsOf: fileURL),
      var stored = try? decoder.decode(PersistedAnalyticsQueue.self, from: data)
    else {
      return PersistedAnalyticsQueue()
    }
    let cutoff = now.addingTimeInterval(-ttl)
    stored.events.removeAll { $0.timestamp < cutoff }
    stored.feedback.removeAll { $0.timestamp < cutoff }
    return stored
  }

  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()
}
