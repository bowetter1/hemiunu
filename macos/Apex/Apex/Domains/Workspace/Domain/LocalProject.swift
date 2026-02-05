import Foundation

struct LocalProject: Identifiable {
    let name: String
    let path: URL
    let modifiedAt: Date
    let hasPackageJson: Bool
    let hasGit: Bool
    let hasDockerfile: Bool
    var briefTitle: String? = nil
    var agentName: String? = nil

    var id: String { name }
}

struct LocalProjectGroup: Identifiable {
    let sessionName: String
    let projects: [LocalProject]

    var id: String { sessionName }

    var displayName: String {
        if let title = projects.first?.briefTitle {
            return title
        }
        return dateLabel
    }

    var hasBriefTitle: Bool {
        projects.first?.briefTitle != nil
    }

    var dateLabel: String {
        guard sessionName.hasPrefix("session-") else { return sessionName }
        let datePart = String(sessionName.dropFirst("session-".count))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        guard let date = formatter.date(from: datePart) else { return sessionName }
        let display = DateFormatter()
        display.dateFormat = "MMM d, HH:mm"
        return display.string(from: date)
    }

    var latestModified: Date {
        projects.map(\.modifiedAt).max() ?? .distantPast
    }

    static func group(_ projects: [LocalProject]) -> [LocalProjectGroup] {
        var sessionMap: [String: [LocalProject]] = [:]
        var standalone: [LocalProject] = []

        for project in projects {
            let parts = project.name.components(separatedBy: "/")
            if parts.count == 2 {
                sessionMap[parts[0], default: []].append(project)
            } else {
                standalone.append(project)
            }
        }

        var groups: [LocalProjectGroup] = []
        for (session, members) in sessionMap {
            groups.append(LocalProjectGroup(
                sessionName: session,
                projects: members.sorted { $0.name < $1.name }
            ))
        }
        for project in standalone {
            groups.append(LocalProjectGroup(
                sessionName: project.name,
                projects: [project]
            ))
        }

        return groups.sorted { $0.latestModified > $1.latestModified }
    }
}

struct LocalFileInfo: Identifiable {
    let path: String
    let isDirectory: Bool
    let size: Int

    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
}
