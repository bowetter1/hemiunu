import Foundation
import CoreServices

/// Watches a directory tree for file changes using macOS FSEvents.
///
/// FSEvents is a kernel-level API that monitors all file system operations
/// (create, modify, delete, rename) recursively within a directory.
/// Events are batched using a configurable latency window (default 0.5s)
/// so rapid writes (e.g. a builder saving 10 files) produce a single callback.
final class FileWatcher {
    private var stream: FSEventStreamRef?
    nonisolated(unsafe) private var callback: (() -> Void)?

    /// Start watching a directory tree. Calls onChange on main thread when files change.
    func watch(directory: URL, onChange: @escaping () -> Void) {
        stop()
        callback = onChange

        let path = directory.path as CFString
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let stream = FSEventStreamCreate(
            nil,
            fileWatcherCallback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // latency — batches events within this window
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else { return }

        self.stream = stream
        // Dispatch to main queue so callback fires on main thread
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }

    /// Stop watching.
    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        callback = nil
    }

    fileprivate func handleEvents() {
        callback?()
    }
}

// C function pointer required by FSEventStreamCreate — dispatches to the FileWatcher instance
private func fileWatcherCallback(
    _ streamRef: ConstFSEventStreamRef,
    _ clientCallBackInfo: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
    watcher.handleEvents()
}
