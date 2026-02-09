import Foundation
import AppKit
import AuthenticationServices
import FirebaseAuth

/// Keeps ASWebAuthenticationSession alive during the OAuth flow
@MainActor
private enum AuthSessionStore {
    nonisolated(unsafe) static var current: ASWebAuthenticationSession?
}

/// Provides the window for ASWebAuthenticationSession
private class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? ASPresentationAnchor()
    }
}

/// Authentication service — Google OAuth via ASWebAuthenticationSession + Firebase
@MainActor
struct AuthService {

    // MARK: - Google OAuth constants

    private static let tokenEndpoint = "https://oauth2.googleapis.com/token"

    private struct GoogleConfig {
        let clientID: String
        let reversedClientID: String
    }

    nonisolated(unsafe) private static var cachedGoogleConfig: GoogleConfig?

    private static func loadGoogleConfig() throws -> GoogleConfig {
        if let cachedGoogleConfig {
            return cachedGoogleConfig
        }

        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let raw = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            throw AuthError.configMissing("Missing GoogleService-Info.plist")
        }

        guard let clientID = raw["CLIENT_ID"] as? String, !clientID.isEmpty,
              let reversedClientID = raw["REVERSED_CLIENT_ID"] as? String, !reversedClientID.isEmpty else {
            throw AuthError.configMissing("Invalid GoogleService-Info.plist")
        }

        let config = GoogleConfig(clientID: clientID, reversedClientID: reversedClientID)
        cachedGoogleConfig = config
        return config
    }

    // MARK: - Google Sign-In → Firebase

    /// Sign in with Google via ASWebAuthenticationSession, then Firebase
    func signInWithGoogle() async throws -> String {
        let config = try Self.loadGoogleConfig()
        let redirectURI = "\(config.reversedClientID):/oauthredirect"

        let nonce = UUID().uuidString
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "nonce", value: nonce),
        ]
        let authURL = components.url!

        let callbackScheme = config.reversedClientID
        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let contextProvider = WebAuthContextProvider()
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { url, error in
                _ = contextProvider
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: AuthError.noCallbackURL)
                }
            }
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = contextProvider
            AuthSessionStore.current = session
            session.start()
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.noAuthCode
        }

        let (idToken, accessToken) = try await exchangeCodeForTokens(
            code: code,
            clientID: config.clientID,
            redirectURI: redirectURI
        )

        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let authResult = try await Auth.auth().signIn(with: credential)
        let firebaseToken = try await authResult.user.getIDToken()
        return firebaseToken
    }

    /// Exchange authorization code for Google ID token + access token
    private func exchangeCodeForTokens(
        code: String,
        clientID: String,
        redirectURI: String
    ) async throws -> (idToken: String, accessToken: String) {
        var request = URLRequest(url: URL(string: Self.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Token exchange failed"
            throw AuthError.tokenExchangeFailed(msg)
        }

        struct GoogleTokenResponse: Codable {
            let id_token: String
            let access_token: String
        }

        let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        return (tokenResponse.id_token, tokenResponse.access_token)
    }

    /// Refresh the Firebase ID token
    func refreshToken() async throws -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        return try await user.getIDToken()
    }

    /// Whether a Firebase user session exists
    var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    /// Sign out of Firebase
    func logout() {
        try? Auth.auth().signOut()
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case configMissing(String)
    case noCallbackURL
    case noAuthCode
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .configMissing(let msg): return msg
        case .noCallbackURL: return "No callback URL received"
        case .noAuthCode: return "No auth code in callback"
        case .tokenExchangeFailed(let msg): return "Token exchange failed: \(msg)"
        }
    }
}
