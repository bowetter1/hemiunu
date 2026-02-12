import SwiftUI

/// Full-width chat bubble (used in ChatPanel)
struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        let deployURL = message.role == .assistant ? extractDeployURL(from: message.content) : nil
        let displayContent = deployURL != nil ? stripDeployURL(from: message.content) : message.content

        return HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                if !displayContent.isEmpty {
                    linkifiedText(displayContent, fontSize: 13)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(message.role == .user ? .white : .primary)
                        .background { bubbleBackground }
                        .clipShape(.rect(cornerRadius: 16))
                }

                if let url = deployURL {
                    DeployLinkCard(url: url)
                }
            }

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

            linkifiedText(message.content, fontSize: 12)
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

// MARK: - Deploy Link Card

/// Inline card shown below chat bubble when a deploy URL is detected
private struct DeployLinkCard: View {
    let url: String

    @State private var isCopied = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.green.gradient, in: .rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text("Live Preview")
                    .font(.system(size: 11, weight: .semibold))
                Text(shortURL)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
                isCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isCopied = false }
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy URL")

            Button {
                if let nsURL = URL(string: url) {
                    NSWorkspace.shared.open(nsURL)
                }
            } label: {
                Text("Open")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6), in: .rect(cornerRadius: 10))
    }

    private var shortURL: String {
        // Show just the sandbox ID prefix for brevity
        url.replacingOccurrences(of: "https://", with: "")
    }
}

/// Extract a Daytona deploy URL from message content
private func extractDeployURL(from content: String) -> String? {
    guard let range = content.range(of: #"https://\d+-[a-f0-9-]+\.proxy\.daytona\.\w+"#, options: .regularExpression) else {
        return nil
    }
    return String(content[range])
}

/// Strip deploy URLs and markdown link wrappers from message text
private func stripDeployURL(from content: String) -> String {
    var result = content
    // Remove markdown links: [url](url)
    result = result.replacingOccurrences(
        of: #"\[https://\d+-[a-f0-9-]+\.proxy\.daytona\.\w+\]\(https://\d+-[a-f0-9-]+\.proxy\.daytona\.\w+\)"#,
        with: "",
        options: .regularExpression
    )
    // Remove bare URLs
    result = result.replacingOccurrences(
        of: #"https://\d+-[a-f0-9-]+\.proxy\.daytona\.\w+"#,
        with: "",
        options: .regularExpression
    )
    // Clean up leftover whitespace/newlines
    result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
    return result
}

// MARK: - Linkified Text

/// Detect URLs in text and render them as clickable links
private func linkifiedText(_ content: String, fontSize: CGFloat) -> Text {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
        return Text(content).font(.system(size: fontSize))
    }

    let nsContent = content as NSString
    let matches = detector.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

    guard !matches.isEmpty else {
        return Text(content).font(.system(size: fontSize))
    }

    var attributed = AttributedString()
    var lastEnd = 0

    for match in matches {
        // Plain text before this link
        if match.range.location > lastEnd {
            let plainRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            attributed.append(AttributedString(nsContent.substring(with: plainRange)))
        }

        // The link itself
        let urlString = nsContent.substring(with: match.range)
        var linkChunk = AttributedString(urlString)
        if let url = match.url {
            linkChunk.link = url
            linkChunk.underlineStyle = .single
        }
        attributed.append(linkChunk)

        lastEnd = match.range.location + match.range.length
    }

    // Remaining plain text after last link
    if lastEnd < nsContent.length {
        attributed.append(AttributedString(nsContent.substring(from: lastEnd)))
    }

    return Text(attributed).font(.system(size: fontSize))
}
