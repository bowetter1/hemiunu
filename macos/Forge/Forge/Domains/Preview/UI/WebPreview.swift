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
    var remoteURL: URL? = nil
    var refreshToken: UUID = UUID()
    var sidebarVisible: Bool = true
    var toolsPanelVisible: Bool = true
    var selectedDevice: PreviewDevice = .desktop
    var onElementClicked: ((ClickedElement) -> Void)? = nil
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
                remoteURL: remoteURL,
                refreshToken: refreshToken,
                cornerRadius: cornerRadius,
                onElementClicked: onElementClicked
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

/// Reusable WebKit view for rendering HTML content with element click detection
struct HTMLWebView: NSViewRepresentable {
    let html: String
    var projectId: String? = nil
    var localFileURL: URL? = nil
    var remoteURL: URL? = nil
    var refreshToken: UUID = UUID()
    var cornerRadius: CGFloat = 16
    var onElementClicked: ((ClickedElement) -> Void)? = nil

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler {
        var lastHTML: String?
        var lastLocalUrl: String?
        var lastRemoteUrl: String?
        var lastRefreshToken: UUID?
        var onElementClicked: ((ClickedElement) -> Void)?

        nonisolated func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "elementClicked",
                  let body = message.body as? [String: Any],
                  let tag = body["tag"] as? String,
                  let text = body["text"] as? String,
                  let selector = body["selector"] as? String,
                  let x = body["x"] as? CGFloat,
                  let y = body["y"] as? CGFloat
            else { return }

            let element = ClickedElement(
                tag: tag, text: text, selector: selector,
                screenX: x, screenY: y
            )
            Task { @MainActor in
                onElementClicked?(element)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Use default (persistent) data store for remote URLs (Vite dev server needs WebSocket)
        // and non-persistent for inline HTML to avoid caching stale content
        if remoteURL == nil {
            config.websiteDataStore = .nonPersistent()
        }

        // JS bridge for element click detection
        let controller = config.userContentController
        controller.add(context.coordinator, name: "elementClicked")
        let script = WKUserScript(source: Self.elementDetectionJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        controller.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.underPageBackgroundColor = .clear
        webView.wantsLayer = true
        webView.layer?.cornerRadius = cornerRadius
        webView.layer?.masksToBounds = true
        context.coordinator.onElementClicked = onElementClicked
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onElementClicked = onElementClicked
        webView.layer?.cornerRadius = cornerRadius
        webView.layer?.masksToBounds = true

        // Local file URL: load directly
        if let localURL = localFileURL {
            let urlString = localURL.absoluteString
            if context.coordinator.lastLocalUrl != urlString || context.coordinator.lastRefreshToken != refreshToken {
                context.coordinator.lastLocalUrl = urlString
                context.coordinator.lastRemoteUrl = nil
                context.coordinator.lastRefreshToken = refreshToken
                context.coordinator.lastHTML = nil
                webView.loadFileURL(localURL, allowingReadAccessTo: localURL.deletingLastPathComponent())
            }
            return
        }

        // Remote URL: load directly (for React/Vite/Next dev servers)
        if let remoteURL = remoteURL {
            let urlString = remoteURL.absoluteString
            if context.coordinator.lastRemoteUrl != urlString || context.coordinator.lastRefreshToken != refreshToken {
                context.coordinator.lastRemoteUrl = urlString
                context.coordinator.lastLocalUrl = nil
                context.coordinator.lastRefreshToken = refreshToken
                context.coordinator.lastHTML = nil
                webView.load(URLRequest(url: remoteURL))
            }
            return
        }

        // Inline HTML rendering
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        context.coordinator.lastLocalUrl = nil
        context.coordinator.lastRemoteUrl = nil
        let baseURL = URL(string: "about:blank?t=\(Date().timeIntervalSince1970)")
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    // MARK: - Injected JavaScript

    static let elementDetectionJS = """
    (function() {
        const style = document.createElement('style');
        style.textContent = `
            .__forge-hover {
                outline: 2px solid rgba(99, 102, 241, 0.5) !important;
                outline-offset: 2px;
                cursor: pointer !important;
            }
            .__forge-clicked {
                outline: 2px solid rgba(99, 102, 241, 0.9) !important;
                outline-offset: 2px;
                background-color: rgba(99, 102, 241, 0.05) !important;
            }
        `;
        document.head.appendChild(style);

        let state = {
            lastHovered: null,
            lastClicked: null
        };

        function buildSelector(el) {
            const parts = [];
            let current = el;
            while (current && current !== document.body && parts.length < 4) {
                let sel = current.tagName.toLowerCase();
                if (current.className && typeof current.className === 'string') {
                    const cls = current.className.trim().split(/\\s+/).filter(c => !c.startsWith('__forge'))[0];
                    if (cls) sel += '.' + cls;
                }
                parts.unshift(sel);
                current = current.parentElement;
            }
            return parts.join(' > ');
        }

        document.addEventListener('mouseover', (e) => {
            const el = e.target;
            if (el === state.lastHovered || el === document.body || el === document.documentElement) return;
            if (state.lastHovered) state.lastHovered.classList.remove('__forge-hover');
            el.classList.add('__forge-hover');
            state.lastHovered = el;
        });

        document.addEventListener('mouseout', (e) => {
            if (state.lastHovered) {
                state.lastHovered.classList.remove('__forge-hover');
                state.lastHovered = null;
            }
        });

        document.addEventListener('click', (e) => {
            const el = e.target;
            if (el === document.body || el === document.documentElement) return;

            if (state.lastClicked) state.lastClicked.classList.remove('__forge-clicked');
            el.classList.add('__forge-clicked');
            state.lastClicked = el;

            const rect = el.getBoundingClientRect();
            const text = (el.textContent || '').trim().substring(0, 60);

            window.webkit.messageHandlers.elementClicked.postMessage({
                tag: el.tagName,
                text: text,
                selector: buildSelector(el),
                x: rect.left + rect.width / 2,
                y: rect.top
            });
        }, true);
    })();
    """
}
