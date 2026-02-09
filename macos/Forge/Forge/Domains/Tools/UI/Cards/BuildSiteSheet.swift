import SwiftUI

// MARK: - Build Site Sheet

struct BuildSiteSheet: View {
    @Binding var isPresented: Bool
    var appState: AppState
    var chatViewModel: ChatViewModel

    /// Nav links parsed from the current index.html
    @State private var navLinks: [NavLink] = []
    @State private var selectedLinks: Set<String> = []
    @State private var customPages: [String] = []
    @State private var customPageName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Build Full Site")
                    .font(.system(size: 16, weight: .semibold))
                if navLinks.isEmpty {
                    Text("Add pages to generate. They'll match the style of your current page.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Text("Pages from your navigation. Deselect any you don't need, or add more below.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)

            Divider()

            // Page list
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(navLinks, id: \.name) { link in
                        navLinkRow(link)
                    }

                    if navLinks.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("No navigation links found in index.html")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                    }

                    if !customPages.isEmpty {
                        Divider().padding(.vertical, 6)
                        ForEach(customPages, id: \.self) { name in
                            customPageRow(name)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .frame(maxHeight: 280)

            Divider()

            // Custom page input
            HStack(spacing: 8) {
                TextField("Add page...", text: $customPageName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { addCustomPage() }

                Button(action: addCustomPage) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.purple)
                }
                .buttonStyle(.plain)
                .disabled(customPageName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Text("\(totalSelectedCount) pages")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Button("Build") {
                    buildSite()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(totalSelectedCount == 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 380)
        .onAppear { parseNavLinks() }
    }

    // MARK: - Subviews

    private func navLinkRow(_ link: NavLink) -> some View {
        HStack(spacing: 10) {
            Image(systemName: selectedLinks.contains(link.name) ? "checkmark.square.fill" : "square")
                .font(.system(size: 14))
                .foregroundColor(selectedLinks.contains(link.name) ? .purple : .secondary)

            Text(link.name)
                .font(.system(size: 13))

            if link.isAnchor {
                Text("section")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
            } else if let href = link.href {
                Text(href)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedLinks.contains(link.name) {
                selectedLinks.remove(link.name)
            } else {
                selectedLinks.insert(link.name)
            }
        }
    }

    private func customPageRow(_ name: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.square.fill")
                .font(.system(size: 14))
                .foregroundColor(.purple)

            Text(name)
                .font(.system(size: 13))

            Spacer()

            Button {
                customPages.removeAll { $0 == name }
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private var totalSelectedCount: Int {
        selectedLinks.count + customPages.count
    }

    private func addCustomPage() {
        let name = customPageName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        guard !customPages.contains(name) else { return }
        guard !navLinks.contains(where: { $0.name.lowercased() == name.lowercased() }) else { return }
        customPages.append(name)
        customPageName = ""
    }

    private func parseNavLinks() {
        guard let html = readCurrentHTML() else { return }

        var links: [NavLink] = []
        var seen = Set<String>()

        let navHTML: String
        if let navRegex = try? NSRegularExpression(pattern: "<nav[^>]*>.*?</nav>", options: [.caseInsensitive, .dotMatchesLineSeparators]),
           let navMatch = navRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) {
            navHTML = (html as NSString).substring(with: navMatch.range)
        } else if let headerRegex = try? NSRegularExpression(pattern: "<header[^>]*>.*?</header>", options: [.caseInsensitive, .dotMatchesLineSeparators]),
                  let headerMatch = headerRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) {
            navHTML = (html as NSString).substring(with: headerMatch.range)
        } else {
            return
        }

        let pattern = #"<a\s[^>]*href\s*=\s*"([^"]*)"[^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return }
        let nsString = navHTML as NSString
        let matches = regex.matches(in: navHTML, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            let href = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            let rawText = nsString.substring(with: match.range(at: 2))
            let name = rawText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            links.append(NavLink(
                name: name,
                href: href == "#" || href.isEmpty ? nil : href,
                isAnchor: href.hasPrefix("#") && href != "#"
            ))
        }

        navLinks = links
        selectedLinks = Set(links.map(\.name))
    }

    private func readCurrentHTML() -> String? {
        if let page = appState.pages.first(where: { $0.name == "index.html" }),
           !page.html.isEmpty {
            return page.html
        }
        if let page = appState.pages.first(where: { $0.layoutVariant == nil }),
           !page.html.isEmpty {
            return page.html
        }

        if let previewURL = appState.localPreviewURL {
            let candidates = ["index.html", "proposal/index.html", "dist/index.html", "public/index.html"]
            for candidate in candidates {
                let url = previewURL.appendingPathComponent(candidate)
                if let html = try? String(contentsOf: url, encoding: .utf8) {
                    return html
                }
            }
        }
        return nil
    }

    private func buildSite() {
        var allPages = Array(selectedLinks).sorted()
        allPages.append(contentsOf: customPages)
        guard !allPages.isEmpty else { return }

        let pageList = allPages.joined(separator: ", ")
        let fileList = allPages.map { "\($0.lowercased().replacingOccurrences(of: " ", with: "-")).html" }.joined(separator: ", ")

        let anchorPages = navLinks.filter { $0.isAnchor && selectedLinks.contains($0.name) }.map(\.name)
        var anchorNote = ""
        if !anchorPages.isEmpty {
            anchorNote = "\nNote: \(anchorPages.joined(separator: ", ")) are currently anchor sections on index.html — create them as standalone pages instead."
        }

        let message = """
        Build a full website with these pages: \(pageList).
        Match the design language and style of the existing index.html.
        Create each page as a separate HTML file (\(fileList)).
        Include consistent navigation across all pages linking them together.\(anchorNote)
        """

        chatViewModel.sendMessage(message)
        isPresented = false
    }
}

// MARK: - Models

private struct NavLink {
    let name: String
    let href: String?
    let isAnchor: Bool
}
