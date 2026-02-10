import Foundation

/// Info about an element the user clicked on in the preview
struct ClickedElement: Equatable {
    let tag: String          // "H1", "BUTTON", "IMG"
    let text: String         // First 60 chars of text content
    let selector: String     // CSS selector path, e.g. "section.hero > h1"
    let screenX: CGFloat     // Position in WebView coordinates
    let screenY: CGFloat

    /// Human-readable label, e.g. "Heading: Design websites…"
    var label: String {
        let name: String = switch tag.lowercased() {
        case "h1", "h2", "h3": "Heading"
        case "p": "Paragraph"
        case "button", "a": "Button"
        case "img": "Image"
        case "section": "Section"
        case "nav": "Navigation"
        case "div": "Block"
        case "li": "List item"
        case "footer": "Footer"
        default: tag.lowercased()
        }
        if text.isEmpty { return name }
        let preview = text.count > 40 ? String(text.prefix(40)) + "…" : text
        return "\(name): \"\(preview)\""
    }
}

/// Actions available for a clicked element
enum ElementAction: String, CaseIterable, Identifiable {
    case editText = "Edit text"
    case describe = "Describe change…"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .editText: "pencil"
        case .describe: "text.bubble"
        }
    }
}
