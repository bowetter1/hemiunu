import Foundation

// MARK: - Checklist Progress

struct ChecklistProgress {
    let currentStep: String?
    let completedCount: Int
    let totalCount: Int

    var label: String {
        "\(completedCount)/\(totalCount)"
    }

    var fraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}

// MARK: - Turn Stats

struct TurnStats {
    let durationSeconds: Double
    let totalCostUSD: Double
    let inputTokens: Int
    let outputTokens: Int
    let numTurns: Int

    var formattedDuration: String {
        let s = Int(durationSeconds)
        if s < 60 { return "\(s)s" }
        return "\(s / 60)m \(s % 60)s"
    }

    var formattedCost: String {
        if totalCostUSD < 0.01 {
            return String(format: "<$0.01")
        }
        return String(format: "$%.2f", totalCostUSD)
    }
}

// MARK: - Tool Name Mapper

enum ToolNameMapper {
    /// Convert raw MCP/Claude tool name to a short human-readable label.
    static func friendlyName(for rawName: String) -> String {
        // Strip common MCP prefixes
        let stripped: String
        if rawName.hasPrefix("mcp__apex-tools__apex_") {
            stripped = String(rawName.dropFirst("mcp__apex-tools__apex_".count))
        } else if rawName.hasPrefix("mcp__apex-tools__") {
            stripped = String(rawName.dropFirst("mcp__apex-tools__".count))
        } else if rawName.hasPrefix("mcp__playwright__") {
            stripped = String(rawName.dropFirst("mcp__playwright__".count))
        } else if rawName.hasPrefix("mcp__") {
            // Generic MCP prefix — strip server name
            let parts = rawName.split(separator: "__", maxSplits: 2)
            stripped = parts.count >= 3 ? String(parts[2]) : rawName
        } else {
            stripped = rawName
        }

        // Known tool mappings
        switch stripped {
        // Apex tools
        case "search_photos":           return "Searching photos"
        case "generate_image":          return "Generating image"
        case "img2img":                 return "Restyling image"
        case "chat":                    return "Sending message"
        case "done":                    return "Finishing up"

        // Playwright tools
        case "browser_navigate":        return "Navigating browser"
        case "browser_snapshot":        return "Reading page"
        case "browser_click":           return "Clicking element"
        case "browser_type":            return "Typing text"
        case "browser_take_screenshot": return "Taking screenshot"
        case "browser_evaluate":        return "Running script"
        case "browser_close":           return "Closing browser"
        case "browser_fill_form":       return "Filling form"
        case "browser_tabs":            return "Managing tabs"
        case "browser_wait_for":        return "Waiting"
        case "browser_hover":           return "Hovering element"
        case "browser_select_option":   return "Selecting option"
        case "browser_run_code":        return "Running browser code"
        case "browser_resize":          return "Resizing browser"

        // Claude built-in tools
        case "Read":                    return "Reading file"
        case "Write":                   return "Writing file"
        case "Edit":                    return "Editing file"
        case "Bash":                    return "Running command"
        case "Glob":                    return "Finding files"
        case "Grep":                    return "Searching code"
        case "WebFetch":                return "Fetching page"
        case "WebSearch":               return "Searching web"
        case "Task":                    return "Running subtask"
        case "TodoWrite", "TodoRead":   return "Managing tasks"
        case "NotebookEdit":           return "Editing notebook"

        default:
            // Fallback: humanize snake_case
            let words = stripped.split(separator: "_").map { $0.capitalized }
            if words.isEmpty { return rawName }
            return words.joined(separator: " ") + "\u{2026}"
        }
    }
}
