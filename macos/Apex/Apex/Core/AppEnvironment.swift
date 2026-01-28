import Foundation

enum AppEnvironment {
    #if DEBUG
    static let apiBaseURL = "https://apex-server-production-a540.up.railway.app"
    #else
    static let apiBaseURL = "https://apex-server-production-a540.up.railway.app"
    #endif

    static let wsBaseURL: String = {
        apiBaseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
    }()
}
