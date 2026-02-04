import Foundation

/// Configuration for project generation — controls which tools/phases are used
struct GenerationConfig: Codable {
    // Research phase
    var skipClarification: Bool = true
    var webSearchCompany: Bool = true
    var scrapeCompanySite: Bool = true
    var findInspirationSites: Bool = true
    var inspirationSiteCount: Int = 3  // kept for API compat, not exposed in UI

    // Layout generation
    var webSearchDuringLayout: Bool = true
    var layoutCount: Int = 1

    // Quality controls
    var researchModel: String = "haiku"
    var layoutModel: String = "sonnet"
    var layoutProvider: String = "anthropic"  // "anthropic" or "openai"

    // Local CLI build — which agents to use (empty = server-side)
    var localAgents: [String] = []  // ["claude", "gemini", "codex"]

    enum CodingKeys: String, CodingKey {
        case skipClarification = "skip_clarification"
        case webSearchCompany = "web_search_company"
        case scrapeCompanySite = "scrape_company_site"
        case findInspirationSites = "find_inspiration_sites"
        case inspirationSiteCount = "inspiration_site_count"
        case webSearchDuringLayout = "web_search_during_layout"
        case layoutCount = "layout_count"
        case researchModel = "research_model"
        case layoutModel = "layout_model"
        case layoutProvider = "layout_provider"
        case localAgents = "local_agents"
    }
}
