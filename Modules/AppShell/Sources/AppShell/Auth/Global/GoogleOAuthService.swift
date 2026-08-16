import AuthenticationServices
import Foundation

#if os(iOS)
  import UIKit
#endif

enum GlobalOAuthError: Error, Equatable {
  case authorizationFailed
  case cancelled
  case invalidCallback
  case invalidTokenResponse
  case randomnessUnavailable
  case unsupportedPlatform
}

@MainActor
protocol GoogleOAuthAuthorizing {
  func authorize() async throws -> String
}

struct GoogleOAuthConfiguration: Sendable, Equatable {
  static let meetPR = GoogleOAuthConfiguration(
    clientID:
      "1070098660233-mntdt18uc68d9gdc3di1f07s2pbofncs.apps.googleusercontent.com",
    redirectURI:
      "com.googleusercontent.apps.1070098660233-mntdt18uc68d9gdc3di1f07s2pbofncs:/oauth2redirect"
  )

  let clientID: String
  let redirectURI: String

  var callbackScheme: String {
    redirectURI.split(separator: ":", maxSplits: 1).first.map(String.init) ?? ""
  }

  func authorizationURL(codeChallenge: String, state: String) throws -> URL {
    var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
    components?.queryItems = [
      URLQueryItem(name: "client_id", value: clientID),
      URLQueryItem(name: "redirect_uri", value: redirectURI),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "scope", value: "openid email profile"),
      URLQueryItem(name: "code_challenge", value: codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "state", value: state),
    ]
    guard let url = components?.url else {
      throw GlobalOAuthError.authorizationFailed
    }
    return url
  }

  func tokenRequest(code: String, verifier: String) throws -> URLRequest {
    guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
      throw GlobalOAuthError.authorizationFailed
    }
    var components = URLComponents()
    components.queryItems = [
      URLQueryItem(name: "client_id", value: clientID),
      URLQueryItem(name: "code", value: code),
      URLQueryItem(name: "code_verifier", value: verifier),
      URLQueryItem(name: "grant_type", value: "authorization_code"),
      URLQueryItem(name: "redirect_uri", value: redirectURI),
    ]

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
    request.setValue("application/json", forHTTPHeaderField: "accept")
    return request
  }
}

struct GoogleOAuthHTTPResponse: Sendable, Equatable {
  let data: Data
  let statusCode: Int
}

@MainActor
final class GoogleOAuthService: NSObject, GoogleOAuthAuthorizing {
  typealias Fetch = @Sendable (URLRequest) async throws -> GoogleOAuthHTTPResponse

  private let configuration: GoogleOAuthConfiguration
  private let fetch: Fetch

  #if os(iOS)
    private let presentationContext = GoogleOAuthPresentationContext()
    private var authenticationSession: ASWebAuthenticationSession?
  #endif

  init(
    configuration: GoogleOAuthConfiguration = .meetPR,
    fetch: @escaping Fetch = { request in
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw GlobalOAuthError.invalidTokenResponse
      }
      return GoogleOAuthHTTPResponse(data: data, statusCode: httpResponse.statusCode)
    }
  ) {
    self.configuration = configuration
    self.fetch = fetch
  }

  func authorize() async throws -> String {
    #if os(iOS)
      let verifier = try GlobalAuthCrypto.codeVerifier()
      let state = UUID().uuidString
      let authorizationURL = try configuration.authorizationURL(
        codeChallenge: GlobalAuthCrypto.codeChallenge(for: verifier),
        state: state
      )
      let callbackURL = try await openAuthorizationPage(
        authorizationURL,
        callbackScheme: configuration.callbackScheme
      )
      let code = try authorizationCode(from: callbackURL, expectedState: state)
      return try await exchangeCode(code, verifier: verifier)
    #else
      throw GlobalOAuthError.unsupportedPlatform
    #endif
  }

  func exchangeCode(_ code: String, verifier: String) async throws -> String {
    let response = try await fetch(configuration.tokenRequest(code: code, verifier: verifier))
    guard 200..<300 ~= response.statusCode else {
      throw GlobalOAuthError.invalidTokenResponse
    }
    let token = try JSONDecoder().decode(GoogleTokenResponse.self, from: response.data)
    guard !token.idToken.isEmpty else {
      throw GlobalOAuthError.invalidTokenResponse
    }
    return token.idToken
  }

  #if os(iOS)
    private func openAuthorizationPage(
      _ url: URL,
      callbackScheme: String
    ) async throws -> URL {
      try await withCheckedThrowingContinuation { continuation in
        let session = ASWebAuthenticationSession(
          url: url,
          callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
          Task { @MainActor [weak self] in
            self?.authenticationSession = nil
            if let authenticationError = error as? ASWebAuthenticationSessionError,
              authenticationError.code == .canceledLogin
            {
              continuation.resume(throwing: GlobalOAuthError.cancelled)
            } else if error != nil {
              continuation.resume(throwing: GlobalOAuthError.authorizationFailed)
            } else if let callbackURL {
              continuation.resume(returning: callbackURL)
            } else {
              continuation.resume(throwing: GlobalOAuthError.invalidCallback)
            }
          }
        }
        session.presentationContextProvider = presentationContext
        session.prefersEphemeralWebBrowserSession = true
        authenticationSession = session
        guard session.start() else {
          authenticationSession = nil
          continuation.resume(throwing: GlobalOAuthError.authorizationFailed)
          return
        }
      }
    }

    private func authorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
      guard
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
        components.queryItems?.first(where: { $0.name == "state" })?.value == expectedState,
        let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
        !code.isEmpty
      else {
        throw GlobalOAuthError.invalidCallback
      }
      return code
    }
  #endif
}

private struct GoogleTokenResponse: Decodable {
  let idToken: String

  private enum CodingKeys: String, CodingKey {
    case idToken = "id_token"
  }
}

#if os(iOS)
  @MainActor
  private final class GoogleOAuthPresentationContext: NSObject,
    ASWebAuthenticationPresentationContextProviding
  {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      if let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
        return window
      }
      return ASPresentationAnchor()
    }
  }
#endif
