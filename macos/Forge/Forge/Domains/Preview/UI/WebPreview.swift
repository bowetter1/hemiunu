import SwiftUI
import WebKit

enum PreviewDevice: String, CaseIterable {
    case desktop
    case tablet
    case mobile
}

/// Live preview of HTML content
struct WebPreview: View {
    let html: String
    var projectId: String? = nil
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
            if !sidebarVisible { width += sidebarWidth }
            if !toolsPanelVisible { width += toolsPanelWidth }
            return width
        case .tablet:
            return 768
        case .mobile:
            return 375
        }
    }

    var body: some View {
        HTMLWebView(html: html, projectId: projectId, localFileURL: localFileURL, refreshToken: refreshToken)
            .frame(width: previewWidth)
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            .animation(.easeInOut(duration: 0.2), value: previewWidth)
            .padding(20)
    }
}

/// Version history dots
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
        .background(Theme.Colors.glassFill)
        .cornerRadius(10)
    }
}

/// Reusable WebKit view for rendering HTML content
struct HTMLWebView: NSViewRepresentable {
    let html: String
    var projectId: String? = nil
    var localFileURL: URL? = nil
    var refreshToken: UUID = UUID()

    final class Coordinator {
        var lastHTML: String?
        var lastLocalUrl: String?
        var lastRefreshToken: UUID?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Local file URL
        if let localURL = localFileURL {
            let urlString = localURL.absoluteString
            if context.coordinator.lastLocalUrl != urlString || context.coordinator.lastRefreshToken != refreshToken {
                context.coordinator.lastLocalUrl = urlString
                context.coordinator.lastRefreshToken = refreshToken
                context.coordinator.lastHTML = nil
                webView.loadFileURL(localURL, allowingReadAccessTo: localURL.deletingLastPathComponent())
            }
            return
        }

        // Inline HTML rendering
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        context.coordinator.lastLocalUrl = nil
        let baseURL = URL(string: "about:blank?t=\(Date().timeIntervalSince1970)")
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}
