import Foundation
import SwiftUI

private struct DomainMoveCandidate: Identifiable {
    let raw: String
    let filePath: String?
    let line: Int?

    var id: String { raw }
}

extension CodeModeView {
    @ViewBuilder
    var codexDomainReportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            insightSectionHeader("Domain Architecture (Codex)")

            if let report = latestDomainReport {
                let domains = domainReportLines(section: "DETECTED_DOMAINS", from: report)
                let moves = parseDomainMoveCandidates(from: report)
                let boundaryIssues = domainReportLines(section: "BOUNDARY_ISSUES", from: report)

                if domains.isEmpty {
                    insightInfo("No detected domains parsed from latest report.")
                } else {
                    ForEach(Array(domains.prefix(6).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 6))
                    }
                }

                if moves.isEmpty {
                    insightInfo("No move candidates parsed yet.")
                } else {
                    ForEach(moves.prefix(6)) { candidate in
                        if let path = candidate.filePath {
                            let lineSuffix = candidate.line.map { ":\($0)" } ?? ""
                            insightRow(
                                title: "Move candidate: \(path)\(lineSuffix)",
                                subtitle: candidate.raw,
                                badge: "MOVE",
                                badgeColor: .blue,
                                onTap: { openFile(path) }
                            )
                        } else {
                            Text(candidate.raw)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                                .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 6))
                        }
                    }
                }

                if let firstIssue = boundaryIssues.first {
                    insightInfo("Boundary issue: \(firstIssue)")
                }
            } else {
                insightInfo("No domain report yet. Run Domain Scan to let Codex map domains and move candidates.")
                Button(action: runDeepScan) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 10))
                        Text("Run Domain Scan")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var latestDomainReport: String? {
        appState.chatViewModel.messages.reversed().first { message in
            guard message.role == .assistant else { return false }
            return message.content.contains("DETECTED_DOMAINS")
                || message.content.contains("MOVE_CANDIDATES")
        }?.content
    }

    private func domainReportLines(section: String, from report: String) -> [String] {
        let lines = report.components(separatedBy: .newlines)
        var inSection = false
        var results: [String] = []

        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "```" { continue }

            if trimmed.hasPrefix("### ") || trimmed.hasPrefix("## ") {
                let heading = trimmed
                    .replacingOccurrences(of: "#", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
                if heading == section {
                    inSection = true
                    continue
                }
                if inSection {
                    break
                }
                continue
            }

            guard inSection else { continue }
            if trimmed.hasPrefix("- ") {
                results.append(String(trimmed.dropFirst(2)))
            } else if let dotIndex = trimmed.firstIndex(of: "."), trimmed[..<dotIndex].allSatisfy({ $0.isNumber }) {
                let nextIndex = trimmed.index(after: dotIndex)
                results.append(String(trimmed[nextIndex...]).trimmingCharacters(in: .whitespaces))
            }
        }

        return results
    }

    private func parseDomainMoveCandidates(from report: String) -> [DomainMoveCandidate] {
        domainReportLines(section: "MOVE_CANDIDATES", from: report).map { line in
            let extracted = extractFilePathAndLine(from: line)
            return DomainMoveCandidate(
                raw: line,
                filePath: extracted?.path,
                line: extracted?.line
            )
        }
    }

    private func extractFilePathAndLine(from line: String) -> (path: String, line: Int?)? {
        let pattern = #"([A-Za-z0-9_./\-]+\.[A-Za-z0-9]+)(?::([0-9]+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else { return nil }

        let pathRange = match.range(at: 1)
        guard pathRange.location != NSNotFound else { return nil }
        let rawPath = nsLine.substring(with: pathRange)
        let normalizedPath = rawPath
            .trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            .replacingOccurrences(of: "\\", with: "/")
            .replacingOccurrences(of: "./", with: "")

        var extractedLine: Int?
        if match.numberOfRanges > 2 {
            let lineRange = match.range(at: 2)
            if lineRange.location != NSNotFound {
                extractedLine = Int(nsLine.substring(with: lineRange))
            }
        }

        return normalizedPath.isEmpty ? nil : (path: normalizedPath, line: extractedLine)
    }
}
