import SwiftUI

/// Full-width chat bubble (used in ChatPanel)
struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            Text(message.content)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(message.role == .user ? .white : .primary)
                .background { bubbleBackground }
                .clipShape(.rect(cornerRadius: 16))

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.role == .user {
            LinearGradient(colors: [.blue, .blue.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Color(nsColor: .windowBackgroundColor).opacity(0.6)
        }
    }
}

/// Compact chat bubble (used in ChatTabContent — sidebar)
struct SidebarChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 20) }

            Text(message.content)
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(message.role == .user ? .white : .primary)
                .background { sidebarBubbleBackground }
                .clipShape(.rect(cornerRadius: 12))

            if message.role == .assistant { Spacer(minLength: 20) }
        }
    }

    @ViewBuilder
    private var sidebarBubbleBackground: some View {
        if message.role == .user {
            LinearGradient(colors: [.blue, .blue.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Color(nsColor: .windowBackgroundColor).opacity(0.6)
        }
    }
}
