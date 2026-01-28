import Foundation
import AppKit
import AuthenticationServices
import FirebaseAuth

/// Keeps ASWebAuthenticationSession alive during the OAuth flow
private enum AuthSessionStore {
    static var current: ASWebAuthenticationSession?
}

/// Provides the window for ASWebAuthenticationSession
private class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? ASPresentationAnchor()
    }
}

/// Authentication service — Google OAuth via ASWebAuthenticationSession + Firebase
struct AuthService {
    let client: APIClient

    private struct TokenResponse: Codable {
        let access_token: String
        let token_type: String
    }

    // MARK: - Google OAuth constants

    private static let tokenEndpoint = "https://oauth2.googleapis.com/token"

    private struct GoogleConfig {
        let clientID: String
        let reversedClientID: String
    }

    private static var cachedGoogleConfig: GoogleConfig?

    private static func loadGoogleConfig() throws -> GoogleConfig {
        if let cachedGoogleConfig {
            return cachedGoogleConfig
        }

        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let raw = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            throw APIClient.APIError.server(status: 400, message: "Missing GoogleService-Info.plist")
        }

        guard let clientID = raw["CLIENT_ID"] as? String, !clientID.isEmpty,
              let reversedClientID = raw["REVERSED_CLIENT_ID"] as? String, !reversedClientID.isEmpty else {
            throw APIClient.APIError.server(status: 400, message: "Invalid GoogleService-Info.plist")
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

        // 1. Build Google OAuth URL
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

        // 2. Present browser via ASWebAuthenticationSession
        let callbackScheme = config.reversedClientID
        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let contextProvider = WebAuthContextProvider()
                let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { url, error in
                    _ = contextProvider // prevent deallocation
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: APIClient.APIError.server(status: 400, message: "No callback URL"))
                    }
                }
                session.prefersEphemeralWebBrowserSession = false
                session.presentationContextProvider = contextProvider
                AuthSessionStore.current = session
                session.start()
            }
        }

        // 3. Extract auth code from callback
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw APIClient.APIError.server(status: 400, message: "No auth code in callback")
        }

        // 4. Exchange code for tokens
        let (idToken, accessToken) = try await exchangeCodeForTokens(
            code: code,
            clientID: config.clientID,
            redirectURI: redirectURI
        )

        // 5. Sign in to Firebase with Google credential
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let authResult = try await Auth.auth().signIn(with: credential)
        let firebaseToken = try await authResult.user.getIDToken()

        await MainActor.run {
            client.authToken = firebaseToken
        }

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
            throw APIClient.APIError.server(status: 400, message: msg)
        }

        struct GoogleTokenResponse: Codable {
            let id_token: String
            let access_token: String
        }

        let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        return (tokenResponse.id_token, tokenResponse.access_token)
    }

    /// Refresh the Firebase ID token (tokens expire after ~1 hour)
    func refreshToken() async throws -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        let token = try await user.getIDToken()
        await MainActor.run {
            client.authToken = token
        }
        return token
    }

    /// Whether a Firebase user session exists
    var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    // MARK: - Dev Token (DEBUG only)

    /// Get dev token (skips login for development)
    func getDevToken() async throws -> String {
        let url = client.baseURL.appendingPathComponent("/api/v1/auth/dev-token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await NetworkSession.standard.data(for: request)
        let tokenResponse = try client.decodeResponse(TokenResponse.self, data: data, response: response)

        await MainActor.run {
            client.authToken = tokenResponse.access_token
        }

        return tokenResponse.access_token
    }

    // MARK: - Logout

    /// Sign out of Firebase and clear token
    func logout() {
        try? Auth.auth().signOut()
        client.authToken = nil
    }
}
