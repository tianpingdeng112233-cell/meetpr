import CryptoKit
import Foundation
import Security

enum GlobalAuthCrypto {
  static func sha256Hex(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { byte in
      String(byte, radix: 16).leftPadding(toLength: 2, withPad: "0")
    }.joined()
  }

  static func codeVerifier(byteCount: Int = 32) throws -> String {
    var bytes = [UInt8](repeating: 0, count: byteCount)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
      throw GlobalOAuthError.randomnessUnavailable
    }
    return Data(bytes).base64URLEncodedString()
  }

  static func codeChallenge(for verifier: String) -> String {
    Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
  }
}

extension Data {
  fileprivate func base64URLEncodedString() -> String {
    base64EncodedString()
      .replacing("+", with: "-")
      .replacing("/", with: "_")
      .replacing("=", with: "")
  }
}

extension String {
  fileprivate func leftPadding(toLength: Int, withPad character: Character) -> String {
    guard count < toLength else { return self }
    return String(repeating: character, count: toLength - count) + self
  }
}
