import SwiftUI
import WebKit

enum PreviewDevice: String, CaseIterable {
    case desktop
    case laptop
    case tablet
    case mobile
}

/// Live preview of HTML content — fixed device viewport centered behind side panels
struct WebPreview: View {
    let html: String
    var projectId: String? = nil
    var localFileURL: URL? = nil
    var refreshToken: UUID = UUID()
    var sidebarVisible: Bool = true
    var toolsPanelVisible: Bool = true
    var selectedDevice: PreviewDevice = .desktop
    private let cornerRadius: CGFloat = 16
    private let sidebarTotalWidth: CGFloat = 212
    private let toolsPanelTotalWidth: CGFloat = 312

    private var viewportWidth: CGFloat {
        switch selectedDevice {
        case .desktop: return 1280
        case .laptop: return 1024
        case .tablet: return 768
        case .mobile: return 375
        }
    }

    private var horizontalOffset: CGFloat {
        let sidebarSpace: CGFloat = sidebarVisible ? sidebarTotalWidth : 0
        let toolsSpace: CGFloat = toolsPanelVisible ? toolsPanelTotalWidth : 0
        return (sidebarSpace - toolsSpace) / 2
    }

    var body: some View {
        GeometryReader { geo in
            HTMLWebView(
                html: html,
                projectId: projectId,
                localFileURL: localFileURL,
                refreshToken: refreshToken,
                cornerRadius: cornerRadius
            )
                .frame(width: viewportWidth, height: geo.size.height)
                .clipShape(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                    style: FillStyle(antialiased: false)
                )
                .position(x: geo.size.width / 2 + horizontalOffset, y: geo.size.height / 2)
                .animation(.easeInOut(duration: 0.25), value: selectedDevice)
                .animation(.easeInOut(duration: 0.2), value: sidebarVisible)
                .animation(.easeInOut(duration: 0.2), value: toolsPanelVisible)
        }
        .clipped()
    }
}

/// Version history dots — clickable to navigate between versions
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
        .glassEffect(.regular, in: .rect(cornerRadius: 10, style: .continuous))
    }
}

/// Reusable WebKit view for rendering HTML content
struct HTMLWebView: NSViewRepresentable {
    let html: String
    var projectId: String? = nil
    var localFileURL: URL? = nil
    var refreshToken: UUID = UUID()
    var cornerRadius: CGFloat = 16

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
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.underPageBackgroundColor = .clear
        webView.wantsLayer = true
        webView.layer?.cornerRadius = cornerRadius
        webView.layer?.masksToBounds = true
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.layer?.cornerRadius = cornerRadius
        webView.layer?.masksToBounds = true

        // Local file URL: load directly
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
