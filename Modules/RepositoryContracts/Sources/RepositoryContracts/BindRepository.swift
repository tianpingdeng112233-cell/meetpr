import CoreModels
import Foundation

/// Typed mirror of the backend bind/invite machine codes (spec 031 §3).
/// Repository implementations translate `{ "error": "<CODE>" }` envelopes
/// into these cases; UI behavior is keyed on them — never on raw strings.
public enum BindRequestError: Error, Equatable, Sendable {
  /// 400 INVITE_CODE_INVALID — unknown / revoked / expired / used up.
  /// The backend deliberately does not distinguish (enumeration defense).
  case invalidCode
  /// 409 BIND_REQUEST_ALREADY_PENDING
  case alreadyPending
  /// 409 BIND_ALREADY_BOUND
  case alreadyBound
  /// 409 BIND_REQUEST_NOT_PENDING — cancel raced a coach response.
  case notPending
  /// 404 BIND_REQUEST_NOT_FOUND / INVITE_CODE_NOT_FOUND
  case notFound
}

extension BindRequestError {
  /// Machine-code mapping (spec 031 §3). Backend repositories feed the
  /// envelope code parsed by Networking's BackendErrorEnvelope; nil means
  /// "not a bind code — rethrow the original error".
  public init?(machineCode: String?) {
    switch machineCode {
    case "INVITE_CODE_INVALID": self = .invalidCode
    case "BIND_REQUEST_ALREADY_PENDING": self = .alreadyPending
    case "BIND_ALREADY_BOUND": self = .alreadyBound
    case "BIND_REQUEST_NOT_PENDING": self = .notPending
    case "BIND_REQUEST_NOT_FOUND", "INVITE_CODE_NOT_FOUND": self = .notFound
    default: return nil
    }
  }
}

/// Student-side bind requests (spec 031). Maps 1:1 onto the backend
/// /bind-requests endpoints. No cache by design: bind state must be live —
/// a stale "pending" would hide an acceptance.
public protocol BindRepository: Sendable {
  /// `code` must be normalized (uppercased, separators stripped) by the
  /// caller; `displayName` trimmed, 1-100 chars non-empty.
  /// Throws `BindRequestError.invalidCode` / `.alreadyPending` / `.alreadyBound`.
  func submitBindRequest(code: String, displayName: String) async throws -> BindRequest
  /// Latest request for this student, any status (the backend flips lazy
  /// expiry before reading — the client never self-judges expiry). nil when
  /// the student never submitted one.
  func myBindRequest() async throws -> BindRequest?
  /// own + pending → cancelled; non-pending throws `BindRequestError.notPending`.
  func cancelBindRequest(id: UUID) async throws
}
