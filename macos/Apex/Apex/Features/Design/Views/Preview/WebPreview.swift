import SwiftUI
import WebKit

/// Live preview of HTML content - expands when sidebar hidden
struct WebPreview: View {
    let html: String
    var projectId: String? = nil
    var sidebarVisible: Bool = true
    var toolsPanelVisible: Bool = true

    // Version info (optional)
    var versions: [PageVersion] = []
    var currentVersion: Int = 1
    var onRestoreVersion: ((Int) -> Void)? = nil

    private let baseWidth: CGFloat = 800
    private let sidebarWidth: CGFloat = 220
    private let toolsPanelWidth: CGFloat = 220

    private var previewWidth: CGFloat {
        var width = baseWidth
        if !sidebarVisible {
            width += sidebarWidth
        }
        if !toolsPanelVisible {
            width += toolsPanelWidth
        }
        return width
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            previewToolbar
                .padding(.bottom, 12)

            // Preview - centered, expands when sidebar hidden
            HTMLWebView(html: html, projectId: projectId)
                .frame(width: previewWidth)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
                .animation(.easeInOut(duration: 0.2), value: previewWidth)
        }
        .padding(20)
    }

    private var previewToolbar: some View {
        HStack(spacing: 12) {
            // Width indicator
            Text("\(Int(previewWidth))px")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundColor(.secondary)

            Spacer()

            // Version dots (show if there are any versions)
            if !versions.isEmpty {
                VersionDots(
                    versions: versions,
                    currentVersion: currentVersion,
                    onSelect: { version in
                        onRestoreVersion?(version)
                    }
                )
            }

            // Debug: show version count
            Text("v\(currentVersion)")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.5))

            Spacer()

            // Open in browser
            Button {
                openInBrowser()
            } label: {
                Image(systemName: "safari")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open in Browser")
        }
        .frame(width: previewWidth)
        .animation(.easeInOut(duration: 0.2), value: previewWidth)
    }

    private func openInBrowser() {
        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "apex-preview-\(UUID().uuidString.prefix(8)).html"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(fileURL)
        } catch {
            // Failed to open in browser
        }
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

    // API base URL for loading assets
    private var assetsBaseURL: URL? {
        guard let projectId = projectId else { return nil }
        // Point to the assets endpoint so relative image URLs resolve correctly
        let baseURLString = "\(AppEnvironment.apiBaseURL)/api/v1/projects/\(projectId)/assets/"
        return URL(string: baseURLString)
    }

    final class Coordinator {
        var lastHTML: String?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Disable caching
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        // Use assets base URL if available, otherwise fall back to about:blank
        let baseURL = assetsBaseURL ?? URL(string: "about:blank?t=\(Date().timeIntervalSince1970)")
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}
