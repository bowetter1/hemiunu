import SwiftUI
import WebKit

/// Live preview of HTML content - expands when sidebar hidden
struct WebPreview: View {
    let html: String
    var sidebarVisible: Bool = true

    private let baseWidth: CGFloat = 800
    private let sidebarWidth: CGFloat = 220

    private var previewWidth: CGFloat {
        sidebarVisible ? baseWidth : baseWidth + sidebarWidth
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            previewToolbar
                .padding(.bottom, 12)

            // Preview - centered, expands when sidebar hidden
            ScrollView {
                HTMLWebView(html: html)
                    .frame(width: previewWidth, height: 800)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
                    .animation(.easeInOut(duration: 0.2), value: previewWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            print("Failed to open in browser: \(error)")
        }
    }
}

/// Reusable WebKit view for rendering HTML content
struct HTMLWebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}
