import Foundation
import Combine

/// Events received from the WebSocket server
enum WebSocketEvent: Equatable {
    case moodboardReady
    case layoutsReady(count: Int)
    case statusChanged(status: String)
    case pageUpdated(pageId: String)
    case clarificationNeeded(question: String, options: [String])
    case error(message: String)
    case connected
    case disconnected
}

/// WebSocket manager for real-time project updates
class WebSocketManager: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private let baseURL: String
    private var currentProjectId: String?

    @Published var isConnected = false
    @Published var lastEvent: WebSocketEvent?

    init(baseURL: String = "wss://apex-server-production-a540.up.railway.app") {
        self.baseURL = baseURL
    }

    /// Connect to a project's WebSocket
    func connect(projectId: String, token: String) {
        // Don't reconnect if already connected to same project
        if currentProjectId == projectId && isConnected {
            return
        }

        disconnect()
        currentProjectId = projectId

        // Convert https to wss
        let wsURL = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        guard let url = URL(string: "\(wsURL)/api/v1/projects/\(projectId)/ws") else {
            print("Invalid WebSocket URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        isConnected = true
        lastEvent = .connected
        print("WebSocket connecting to \(url)")

        // Start receiving messages
        receiveMessage(forProject: projectId)

        // Start ping timer to keep connection alive
        startPingTimer()
    }

    /// Disconnect from WebSocket
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        currentProjectId = nil
        isConnected = false
    }

    // MARK: - Private

    private func receiveMessage(forProject projectId: String) {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            // Stop if we've switched to a different project
            guard self.currentProjectId == projectId else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue receiving only if still same project
                if self.currentProjectId == projectId {
                    self.receiveMessage(forProject: projectId)
                }

            case .failure:
                // Only log if we're still supposed to be connected to this project
                if self.currentProjectId == projectId {
                    DispatchQueue.main.async {
                        self.isConnected = false
                    }
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        // Handle ping/pong
        if text == "pong" {
            return
        }

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else {
            print("Invalid WebSocket message: \(text)")
            return
        }

        let eventData = json["data"] as? [String: Any] ?? [:]

        DispatchQueue.main.async { [weak self] in
            switch event {
            case "moodboard_ready":
                self?.lastEvent = .moodboardReady

            case "layouts_ready":
                let count = eventData["count"] as? Int ?? 0
                self?.lastEvent = .layoutsReady(count: count)

            case "status_changed":
                let status = eventData["status"] as? String ?? ""
                self?.lastEvent = .statusChanged(status: status)

            case "page_updated":
                let pageId = eventData["page_id"] as? String ?? ""
                self?.lastEvent = .pageUpdated(pageId: pageId)

            case "error":
                let message = eventData["message"] as? String ?? "Unknown error"
                self?.lastEvent = .error(message: message)

            case "clarification_needed":
                let question = eventData["question"] as? String ?? "Please clarify"
                let options = eventData["options"] as? [String] ?? []
                self?.lastEvent = .clarificationNeeded(question: question, options: options)

            default:
                print("Unknown WebSocket event: \(event)")
            }
        }
    }

    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        let message = URLSessionWebSocketTask.Message.string("ping")
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Ping error: \(error)")
            }
        }
    }
}
