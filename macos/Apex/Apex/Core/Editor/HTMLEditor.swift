import Foundation
import SwiftUI

// MARK: - Structured Edit Models

struct StructuredEdit: Codable {
    let action: EditAction
    let selector: String
    let styles: [StyleChange]?
    let text: String?
    let className: String?
    let html: String?

    enum EditAction: String, Codable {
        case updateStyle
        case updateText
        case addClass
        case removeClass
        case delete
        case replaceElement
    }
}

struct StyleChange: Codable {
    let property: String  // camelCase: fontSize, backgroundColor
    let value: String
}

struct StructuredEditResponse: Codable {
    let edits: [StructuredEdit]
    let explanation: String
}

// MARK: - HTML Editor

/// Applies structured edits to HTML locally (no server round-trip for execution)
class HTMLEditor {

    /// Apply a list of structured edits to HTML
    static func apply(edits: [StructuredEdit], to html: String) -> String {
        var result = html

        for edit in edits {
            result = applyEdit(edit, to: result)
        }

        return result
    }

    /// Apply a single edit
    private static func applyEdit(_ edit: StructuredEdit, to html: String) -> String {
        switch edit.action {
        case .updateStyle:
            return applyStyleEdit(edit, to: html)
        case .updateText:
            return applyTextEdit(edit, to: html)
        case .addClass:
            return applyAddClass(edit, to: html)
        case .removeClass:
            return applyRemoveClass(edit, to: html)
        case .delete:
            return applyDelete(edit, to: html)
        case .replaceElement:
            return applyReplace(edit, to: html)
        }
    }

    // MARK: - Style Edits

    private static func applyStyleEdit(_ edit: StructuredEdit, to html: String) -> String {
        guard let styles = edit.styles, !styles.isEmpty else { return html }

        // Convert camelCase to kebab-case for CSS
        let cssProperties = styles.map { style in
            let kebabProperty = camelToKebab(style.property)
            return "\(kebabProperty): \(style.value)"
        }.joined(separator: "; ")

        // Find elements matching selector and add/update inline style
        return updateElementStyle(html: html, selector: edit.selector, newStyles: cssProperties)
    }

    private static func updateElementStyle(html: String, selector: String, newStyles: String) -> String {
        // Parse selector to find element
        // For now, handle common cases: tag, .class, #id, tag.class

        var result = html

        // Try to find element with existing style attribute
        if let range = findElementRange(in: html, selector: selector) {
            let element = String(html[range])

            if element.contains("style=\"") {
                // Append to existing style
                let updated = element.replacingOccurrences(
                    of: "style=\"",
                    with: "style=\"\(newStyles); "
                )
                result = html.replacingCharacters(in: range, with: updated)
            } else {
                // Add style attribute after tag name
                if let tagEndIndex = element.firstIndex(of: ">") {
                    let insertPoint = element.index(before: tagEndIndex)
                    var updated = element
                    let styleAttr = " style=\"\(newStyles)\""

                    // Check if self-closing
                    if element[insertPoint] == "/" {
                        updated.insert(contentsOf: styleAttr, at: insertPoint)
                    } else {
                        updated.insert(contentsOf: styleAttr, at: tagEndIndex)
                    }
                    result = html.replacingCharacters(in: range, with: updated)
                }
            }
        }

        return result
    }

    // MARK: - Text Edits

    private static func applyTextEdit(_ edit: StructuredEdit, to html: String) -> String {
        guard let newText = edit.text else { return html }

        // Find element and replace its text content
        if let (openRange, closeRange) = findElementWithContent(in: html, selector: edit.selector) {
            let beforeContent = html[..<openRange.upperBound]
            let afterContent = html[closeRange.lowerBound...]
            return String(beforeContent) + newText + String(afterContent)
        }

        return html
    }

    // MARK: - Class Edits

    private static func applyAddClass(_ edit: StructuredEdit, to html: String) -> String {
        guard let className = edit.className else { return html }

        if let range = findElementRange(in: html, selector: edit.selector) {
            let element = String(html[range])

            if element.contains("class=\"") {
                // Append to existing class
                let updated = element.replacingOccurrences(
                    of: "class=\"",
                    with: "class=\"\(className) "
                )
                return html.replacingCharacters(in: range, with: updated)
            } else {
                // Add class attribute
                if let tagEndIndex = element.firstIndex(of: ">") {
                    var updated = element
                    updated.insert(contentsOf: " class=\"\(className)\"", at: tagEndIndex)
                    return html.replacingCharacters(in: range, with: updated)
                }
            }
        }

        return html
    }

    private static func applyRemoveClass(_ edit: StructuredEdit, to html: String) -> String {
        guard let className = edit.className else { return html }

        // Remove class from class attribute
        return html
            .replacingOccurrences(of: "class=\"\(className) ", with: "class=\"")
            .replacingOccurrences(of: " \(className)\"", with: "\"")
            .replacingOccurrences(of: "class=\"\(className)\"", with: "")
    }

    // MARK: - Delete/Replace

    private static func applyDelete(_ edit: StructuredEdit, to html: String) -> String {
        if let (openRange, closeRange) = findFullElementRange(in: html, selector: edit.selector) {
            let fullRange = openRange.lowerBound..<closeRange.upperBound
            return html.replacingCharacters(in: fullRange, with: "")
        }
        return html
    }

    private static func applyReplace(_ edit: StructuredEdit, to html: String) -> String {
        guard let newHtml = edit.html else { return html }

        if let (openRange, closeRange) = findFullElementRange(in: html, selector: edit.selector) {
            let fullRange = openRange.lowerBound..<closeRange.upperBound
            return html.replacingCharacters(in: fullRange, with: newHtml)
        }
        return html
    }

    // MARK: - Helpers

    private static func camelToKebab(_ str: String) -> String {
        var result = ""
        for char in str {
            if char.isUppercase {
                result += "-\(char.lowercased())"
            } else {
                result += String(char)
            }
        }
        return result
    }

    /// Find the opening tag range for a selector
    private static func findElementRange(in html: String, selector: String) -> Range<String.Index>? {
        // Parse selector
        let (tag, className, id) = parseSelector(selector)

        // Build regex pattern
        var pattern = "<"
        if let tag = tag {
            pattern += tag
        } else {
            pattern += "\\w+"
        }
        pattern += "[^>]*"

        if let id = id {
            pattern += "id=\"\(id)\"[^>]*"
        }
        if let className = className {
            pattern += "class=\"[^\"]*\\b\(className)\\b[^\"]*\"[^>]*"
        }

        pattern += ">"

        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(html.startIndex..., in: html)
            if let match = regex.firstMatch(in: html, options: [], range: range) {
                return Range(match.range, in: html)
            }
        }

        // Fallback: simple search
        if let tag = tag {
            if let range = html.range(of: "<\(tag)", options: .caseInsensitive) {
                if let endRange = html.range(of: ">", range: range.upperBound..<html.endIndex) {
                    return range.lowerBound..<endRange.upperBound
                }
            }
        }

        return nil
    }

    /// Find element opening and closing positions (for text replacement)
    private static func findElementWithContent(in html: String, selector: String) -> (Range<String.Index>, Range<String.Index>)? {
        guard let openRange = findElementRange(in: html, selector: selector) else { return nil }

        let (tag, _, _) = parseSelector(selector)
        guard let tagName = tag else { return nil }

        // Find closing tag
        let afterOpen = openRange.upperBound
        if let closeRange = html.range(of: "</\(tagName)>", options: .caseInsensitive, range: afterOpen..<html.endIndex) {
            return (openRange, closeRange)
        }

        return nil
    }

    /// Find full element range including content and closing tag
    private static func findFullElementRange(in html: String, selector: String) -> (Range<String.Index>, Range<String.Index>)? {
        guard let openRange = findElementRange(in: html, selector: selector) else { return nil }

        let (tag, _, _) = parseSelector(selector)
        guard let tagName = tag else { return nil }

        // Find closing tag
        let afterOpen = openRange.upperBound
        if let closeRange = html.range(of: "</\(tagName)>", options: .caseInsensitive, range: afterOpen..<html.endIndex) {
            return (openRange, closeRange)
        }

        return nil
    }

    /// Parse CSS selector into components
    private static func parseSelector(_ selector: String) -> (tag: String?, className: String?, id: String?) {
        var tag: String? = nil
        var className: String? = nil
        var id: String? = nil

        var current = selector

        // Extract ID
        if let hashIndex = current.firstIndex(of: "#") {
            let afterHash = current.index(after: hashIndex)
            let endIndex = current[afterHash...].firstIndex(where: { $0 == "." || $0 == " " }) ?? current.endIndex
            id = String(current[afterHash..<endIndex])
            current = String(current[..<hashIndex]) + (endIndex < current.endIndex ? String(current[endIndex...]) : "")
        }

        // Extract class
        if let dotIndex = current.firstIndex(of: ".") {
            let afterDot = current.index(after: dotIndex)
            let endIndex = current[afterDot...].firstIndex(where: { $0 == "." || $0 == " " || $0 == "#" }) ?? current.endIndex
            className = String(current[afterDot..<endIndex])
            current = String(current[..<dotIndex])
        }

        // Remaining is tag
        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            tag = trimmed
        }

        return (tag, className, id)
    }
}
