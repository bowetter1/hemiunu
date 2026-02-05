import SwiftUI
import WebKit

enum PreviewDevice: String, CaseIterable {
    case desktop
    case tablet
    case mobile
}

/// Live preview of HTML content - expands when sidebar hidden
struct WebPreview: View {
    let html: String
    var projectId: String? = nil
    var sandboxPreviewUrl: String? = nil
    var localFileURL: URL? = nil
    var refreshToken: UUID = UUID()
    var sidebarVisible: Bool = true
    var toolsPanelVisible: Bool = true
    var selectedDevice: PreviewDevice = .desktop

    private let baseWidth: CGFloat = 800
    private let sidebarWidth: CGFloat = 220
    private let toolsPanelWidth: CGFloat = 220

    private var previewWidth: CGFloat {
        switch selectedDevice {
        case .desktop:
            var width = baseWidth
            if !sidebarVisible {
                width += sidebarWidth
            }
            if !toolsPanelVisible {
                width += toolsPanelWidth
            }
            return width
        case .tablet:
            return 768
        case .mobile:
            return 375
        }
    }

    var body: some View {
        HTMLWebView(html: html, projectId: projectId, sandboxPreviewUrl: sandboxPreviewUrl, localFileURL: localFileURL, refreshToken: refreshToken)
            .frame(width: previewWidth)
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
            .animation(.easeInOut(duration: 0.2), value: previewWidth)
            .padding(20)
    }
}

/// Version history dots - clickable to navigate between versions
struct VersionDots: View {
    let versions: [PageVersion]
    let currentVersion: Int
    var onSelect: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            ForEach(versions) { version in
                Button {
                    onSelect?(version.version)
                } label: {
                    Circle()
                        .fill(version.version == currentVersion ? Color.blue : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
                .buttonStyle(.plain)
                .help(version.instruction ?? "Version \(version.version)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        .cornerRadius(10)
    }
}

/// Reusable WebKit view for rendering HTML content
struct HTMLWebView: NSViewRepresentable {
    let html: String
    var projectId: String? = nil
    var sandboxPreviewUrl: String? = nil
    var localFileURL: URL? = nil
    var refreshToken: UUID = UUID()

    // API base URL for loading assets
    private var assetsBaseURL: URL? {
        guard let projectId = projectId else { return nil }
        // Point to the assets endpoint so relative image URLs resolve correctly
        let baseURLString = "\(AppEnvironment.apiBaseURL)/api/v1/projects/\(projectId)/assets/"
        return URL(string: baseURLString)
    }

    final class Coordinator {
        var lastHTML: String?
        var lastSandboxUrl: String?
        var lastLocalUrl: String?
        var lastRefreshToken: UUID?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Disable caching
        config.websiteDataStore = .nonPersistent()
        // Allow file access for local previews
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // If we have a local file URL, load it directly
        if let localURL = localFileURL {
            let urlString = localURL.absoluteString
            if context.coordinator.lastLocalUrl != urlString || context.coordinator.lastRefreshToken != refreshToken {
                context.coordinator.lastLocalUrl = urlString
                context.coordinator.lastRefreshToken = refreshToken
                context.coordinator.lastHTML = nil
                context.coordinator.lastSandboxUrl = nil
                webView.loadFileURL(localURL, allowingReadAccessTo: localURL.deletingLastPathComponent())
            }
            return
        }

        // If we have a sandbox preview URL, load it directly
        if let previewUrl = sandboxPreviewUrl, let url = URL(string: previewUrl) {
            if context.coordinator.lastSandboxUrl != previewUrl {
                context.coordinator.lastSandboxUrl = previewUrl
                context.coordinator.lastHTML = nil
                context.coordinator.lastLocalUrl = nil
                webView.load(URLRequest(url: url))
            }
            return
        }

        // Inline HTML rendering
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        context.coordinator.lastSandboxUrl = nil
        context.coordinator.lastLocalUrl = nil
        // Use assets base URL if available, otherwise fall back to about:blank
        let baseURL = assetsBaseURL ?? URL(string: "about:blank?t=\(Date().timeIntervalSince1970)")
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}
