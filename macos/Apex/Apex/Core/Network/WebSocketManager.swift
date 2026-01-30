import Foundation
import Combine

/// Events received from the WebSocket server
enum WebSocketEvent: Equatable {
    case moodboardReady
    case researchReady
    case layoutsReady(count: Int)
    case statusChanged(status: String)
    case pageUpdated(pageId: String)
    case clarificationNeeded(questions: [ClarificationQuestion])
    case error(message: String)
    case connected
    case disconnected
    case reconnecting(attempt: Int)
}

/// WebSocket manager for real-time project updates with automatic reconnection
class WebSocketManager: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectTask: Task<Void, Never>?
    private let baseURL: String
    private var currentProjectId: String?
    private var currentToken: String?

    // Reconnection settings
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 10
    private let baseReconnectDelay: TimeInterval = 1.0
    private let maxReconnectDelay: TimeInterval = 30.0

    @Published var isConnected = false
    @Published var lastEvent: WebSocketEvent?

    init(baseURL: String = AppEnvironment.wsBaseURL) {
        self.baseURL = baseURL
    }

    /// Connect to a project's WebSocket
    func connect(projectId: String, token: String) {
        // Don't reconnect if already connected to same project
        if currentProjectId == projectId && isConnected {
            return
        }

        // Cancel any pending reconnect
        reconnectTask?.cancel()
        reconnectTask = nil

        disconnect(clearCredentials: false)
        currentProjectId = projectId
        currentToken = token
        reconnectAttempt = 0

        performConnect()
    }

    private func performConnect() {
        guard let projectId = currentProjectId, let token = currentToken else {
            return
        }

        // Convert https to wss
        let wsURL = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        guard let url = URL(string: "\(wsURL)/api/v1/projects/\(projectId)/ws") else {
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        DispatchQueue.main.async {
            self.isConnected = true
            self.lastEvent = .connected
            self.reconnectAttempt = 0
        }

        // Start receiving messages
        receiveMessage(forProject: projectId)

        // Start ping timer to keep connection alive
        startPingTimer()
    }

    /// Disconnect from WebSocket
    func disconnect(clearCredentials: Bool = true) {
        pingTimer?.invalidate()
        pingTimer = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        if clearCredentials {
            currentProjectId = nil
            currentToken = nil
            reconnectAttempt = 0
        }

        DispatchQueue.main.async {
            self.isConnected = false
        }
    }

    // MARK: - Reconnection

    private func scheduleReconnect() {
        guard currentProjectId != nil, currentToken != nil else {
            return
        }

        guard reconnectAttempt < maxReconnectAttempts else {
            DispatchQueue.main.async {
                self.lastEvent = .error(message: "Connection lost. Please refresh.")
            }
            return
        }

        reconnectAttempt += 1

        // Exponential backoff with jitter
        let delay = min(baseReconnectDelay * pow(2, Double(reconnectAttempt - 1)), maxReconnectDelay)
        let jitter = Double.random(in: 0...0.5)
        let totalDelay = delay + jitter

        DispatchQueue.main.async {
            self.lastEvent = .reconnecting(attempt: self.reconnectAttempt)
        }

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self?.performConnect()
            }
        }
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
                // Only handle if we're still supposed to be connected to this project
                if self.currentProjectId == projectId {
                    DispatchQueue.main.async {
                        self.isConnected = false
                        self.lastEvent = .disconnected
                    }
                    // Try to reconnect
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        // Handle ping/pong
        if text == "pong" {
            return
        }

        print("[WS] Raw message: \(text.prefix(200))")

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else {
            print("[WS] Failed to parse message as JSON with 'event' key")
            return
        }

        print("[WS] Parsed event: \(event)")

        let eventData = json["data"] as? [String: Any] ?? [:]

        DispatchQueue.main.async { [weak self] in
            switch event {
            case "moodboard_ready":
                self?.lastEvent = .moodboardReady

            case "research_ready":
                self?.lastEvent = .researchReady

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
                // New format: array of questions
                if let rawQuestions = eventData["questions"] as? [[String: Any]] {
                    let questions = rawQuestions.compactMap { q -> ClarificationQuestion? in
                        guard let question = q["question"] as? String,
                              let options = q["options"] as? [String] else { return nil }
                        return ClarificationQuestion(question: question, options: options)
                    }
                    self?.lastEvent = .clarificationNeeded(questions: questions)
                } else {
                    // Legacy single-question fallback
                    let question = eventData["question"] as? String ?? "Please clarify"
                    let options = eventData["options"] as? [String] ?? []
                    self?.lastEvent = .clarificationNeeded(questions: [
                        ClarificationQuestion(question: question, options: options)
                    ])
                }

            default:
                break
            }
        }
    }

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        guard isConnected else { return }

        let message = URLSessionWebSocketTask.Message.string("ping")
        webSocketTask?.send(message) { [weak self] error in
            if error != nil {
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.lastEvent = .disconnected
                }
                self?.scheduleReconnect()
            }
        }
    }
}
