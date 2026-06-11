import CoreModels
import Foundation

/// Shared parser for the backend's `{ "error": "<MACHINE_CODE>", ... }`
/// envelope (same shape AuthErrorEnvelopeDTO decodes; spec 031 §3 / 032 §3
/// reuse it for bind + onboarding endpoints). Networking only extracts the
/// strings; the machine-code → typed-error mapping lives next to the error
/// enums in RepositoryContracts.
public enum BackendErrorEnvelope {
  private struct Envelope: Decodable {
    let error: String
    let missingFields: [String]?
  }

  /// Machine code from an `APIError.httpStatus` payload; nil for transport
  /// failures or non-envelope bodies (treated as generic network errors).
  public static func machineCode(from error: any Error) -> String? {
    decode(from: error)?.error
  }

  /// The 422 ONBOARDING_INCOMPLETE `missing_fields` payload, snake_case
  /// field names verbatim. Empty when the envelope carries none.
  public static func missingFields(from error: any Error) -> [String] {
    decode(from: error)?.missingFields ?? []
  }

  private static func decode(from error: any Error) -> Envelope? {
    guard case APIError.httpStatus(_, let data) = error else { return nil }
    return try? MeetPRCodec.decoder.decode(Envelope.self, from: data)
  }
}
