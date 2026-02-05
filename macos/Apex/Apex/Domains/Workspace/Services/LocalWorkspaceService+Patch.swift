import Foundation

extension LocalWorkspaceService {
    // MARK: - Patch Operations

    /// Apply sed-style text replacement in a file
    func patchFile(project: String, path: String, find: String, replace: String) throws {
        let content = try readFile(project: project, path: path)
        let patched = content.replacingOccurrences(of: find, with: replace)
        try writeFile(project: project, path: path, content: patched)
    }

    /// Apply multiple patches to a project
    func applyPatches(project: String, patches: [FilePatch]) throws -> Int {
        var count = 0
        for patch in patches {
            switch patch.operation {
            case .replace(let find, let replaceWith):
                try patchFile(project: project, path: patch.path, find: find, replace: replaceWith)
                count += 1
            case .write(let content):
                try writeFile(project: project, path: patch.path, content: content)
                count += 1
            case .delete:
                try deleteFile(project: project, path: patch.path)
                count += 1
            }
        }
        return count
    }

}
