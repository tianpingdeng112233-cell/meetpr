import Foundation

/// Small, memory-only cache keyed by the complete signed URL. A refreshed link
/// is a new cache entry; failed requests are never cached.
actor ChatPosterLoader {
  static let shared = ChatPosterLoader()
  private let cache = NSCache<NSURL, NSData>()

  init() {
    cache.totalCostLimit = 24 * 1_024 * 1_024
    cache.countLimit = 64
  }

  func data(for url: URL) async throws -> Data {
    if let data = cache.object(forKey: url as NSURL) { return data as Data }
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode)
    else {
      throw URLError(.badServerResponse)
    }
    try Task.checkCancellation()
    cache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
    return data
  }
}
