import Foundation

/// Wrapper for design WebSocket events
final class DesignWebSocket {
    let manager: WebSocketManager

    init(manager: WebSocketManager = WebSocketManager()) {
        self.manager = manager
    }
}
