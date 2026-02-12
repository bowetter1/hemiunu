import Foundation

/// Errors from AI service calls
enum AIError: LocalizedError {
    case noAPIKey(provider: AIProvider)
    case apiError(status: Int, message: String)
    case invalidResponse
    case streamingFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let provider):
            return "No API key set for \(provider.displayName). Add it in Settings."
        case .apiError(let status, let message):
            return "API error (\(status)): \(message)"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .streamingFailed(let reason):
            return "Streaming failed: \(reason)"
        case .cancelled:
            return "Request was cancelled"
        }
    }
}
