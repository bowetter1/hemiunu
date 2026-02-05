import Foundation

/// Shared URLSession configurations for different timeout requirements
enum NetworkSession {
    /// Standard session (default timeouts)
    static let standard = URLSession.shared

    /// AI generation session (5 minutes) — project creation, clarification, layout generation
    static let aiGeneration: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()

    /// AI editing session (3 minutes) — page edits, structured edits
    static let aiEditing: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config)
    }()

    /// Code generation session (10 minutes) — full project code generation
    static let codeGeneration: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()
}
