import CoreModels
import Foundation

/// Opt-in mixed response. Existing plan-only readers keep their nonoptional slot identity.
public struct AllStudentSetLogsDTO: Decodable, Sendable {
  public let planned: [SetLogDTO]
  public let added: [StudentAddedSetLog]

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: Keys.self)
    var rows = try container.nestedUnkeyedContainer(forKey: .logs)
    var planned: [SetLogDTO] = []
    var added: [StudentAddedSetLog] = []
    while !rows.isAtEnd {
      let row = try rows.superDecoder()
      let identity = try row.container(keyedBy: Keys.self)
      if try identity.decodeIfPresent(Bool.self, forKey: .adhoc) == true {
        added.append(try StudentAddedSetLog(from: row))
      } else {
        planned.append(try SetLogDTO(from: row))
      }
    }
    self.planned = planned
    self.added = added
  }

  private enum Keys: String, CodingKey { case logs, adhoc }
}
