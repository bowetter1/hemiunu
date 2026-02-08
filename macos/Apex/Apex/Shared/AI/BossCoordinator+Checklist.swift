import SwiftUI

extension BossCoordinator {
    // MARK: - Dynamic Checklist

    func generateChecklist(role: WorkspaceRole) -> String {
        let c = buildConfig

        // Research step description
        var researchSteps: [String] = []
        if c.scrapeCompanySite { researchSteps.append("visit site") }
        if c.webSearchCompany { researchSteps.append("web search") }
        if c.findInspirationSites {
            researchSteps.append("find \(c.inspirationSiteCount) inspiration sites + \(c.inspirationSiteCount) competitors")
        }
        let researchDesc = researchSteps.isEmpty
            ? "Write research.md"
            : researchSteps.joined(separator: " + ") + ", write research.md"

        // Build step description
        var buildParts: [String] = []
        if let img = imageInstruction { buildParts.append(img.lowercased()) }
        buildParts.append("one screen, 100vh, no scroll")
        if !c.webSearchDuringLayout { buildParts.append("no web search") }
        if pendingInspirationImage != nil { buildParts.append("see inspiration.jpg") }
        let buildDesc = "Build proposal/index.html (\(buildParts.joined(separator: ", ")))"

        switch role {
        case .research:
            return """
            # Research Checklist

            - [ ] UNDERSTAND — Extract info from user message, write brief.md
            - [ ] RESEARCH — \(researchDesc)
            """

        case .researchDesign:
            return """
            # Research + Design Checklist

            - [ ] UNDERSTAND — Extract info from user message, write brief.md
            - [ ] RESEARCH — \(researchDesc)
            - [ ] DESIGN — Describe 3 distinct design alternatives in designs.md
            - [ ] WIREFRAME — Generate wireframe mockup for each design (wireframe-1.png, 2, 3)
            """

        case .builder:
            return """
            # Builder Checklist

            - [x] UNDERSTAND — (done by research agent)
            - [x] RESEARCH — (done by research agent)
            - [ ] VECTOR — Choose your own unique direction to push the brand
            - [ ] BUILD — \(buildDesc)
            - [ ] REVIEW — Verify all images exist, fix missing
            - [ ] REFINE — Improve based on feedback
            """

        case .solo:
            let understandDesc = c.skipClarification
                ? "Extract info from user message, write brief.md"
                : "Ask questions, write brief.md"

            return """
            # Checklist

            - [ ] UNDERSTAND — \(understandDesc)
            - [ ] RESEARCH — \(researchDesc)
            - [ ] VECTOR — Choose one direction to push the brand, write to research.md
            - [ ] BUILD — \(buildDesc)
            - [ ] REVIEW — Verify all images exist, fix missing
            - [ ] REFINE — Improve based on feedback
            """
        }
    }

}
