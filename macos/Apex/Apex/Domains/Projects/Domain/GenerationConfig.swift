import Foundation

/// Configuration for project generation — controls which tools/phases are used
struct GenerationConfig: Codable {
    // Research phase
    var skipClarification: Bool = true
    var webSearchCompany: Bool = true
    var scrapeCompanySite: Bool = true
    var findInspirationSites: Bool = true
    var inspirationSiteCount: Int = 3

    // Layout generation
    var webSearchDuringLayout: Bool = true

    // Local CLI build — which agents to use (empty = server-side)
    var localAgents: [String] = []  // ["claude", "gemini", "codex"]

    enum CodingKeys: String, CodingKey {
        case skipClarification = "skip_clarification"
        case webSearchCompany = "web_search_company"
        case scrapeCompanySite = "scrape_company_site"
        case findInspirationSites = "find_inspiration_sites"
        case inspirationSiteCount = "inspiration_site_count"
        case webSearchDuringLayout = "web_search_during_layout"
        case localAgents = "local_agents"
    }
}
