import Foundation

@MainActor
protocol BossCoordinatorDelegate: AnyObject {
    func localProjectName(from id: String) -> String?
    func loadProject(id: String) async
    func setSelectedProjectId(_ id: String?)
    func refreshLocalProjects()
    var selectedProjectId: String? { get }
    func setLocalFiles(_ files: [LocalFileInfo])
    var localFiles: [LocalFileInfo] { get }
    func setPages(_ pages: [Page])
    var pages: [Page] { get }
    var selectedPageId: String? { get }
    func setSelectedPageId(_ id: String?)
    func setLocalPreviewURL(_ url: URL?)
    func refreshPreview()
}
