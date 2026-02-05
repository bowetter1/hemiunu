# Forge App — Code Scan Report

**Date:** 2026-02-05
**Scope:** All 57 Swift files in `macos/Forge/`
**App:** Forge — AI-powered web design tool (macOS native, SwiftUI)

---

## Architecture Overview

Forge is a well-structured macOS app using domain-driven design:

```
Forge/
├── App/          — Entry point, AppState (singleton), AppRouter, Topbar
├── Domains/
│   ├── AI/       — AIService protocol, Claude + Groq streaming, SSE parsing
│   ├── Auth/     — Google OAuth → Firebase
│   ├── Chat/     — ChatViewModel, message bubbles, floating chat
│   ├── Design/   — DesignView, BriefBuilder, version management
│   ├── Editor/   — CodeEditor, FileTree, CodeViewModel
│   ├── Preview/  — WKWebView-based HTML preview
│   ├── Projects/ — Project/Page domain models, formatters
│   ├── Tools/    — Right panel (settings, new project, build site)
│   └── Workspace/— Local file/git/shell operations, sidebar
└── Shared/       — HTTPClient, Theme, CommandBar
```

**Total lines:** ~3,600 across 57 files. Clean, focused codebase.

---

## Findings

### 1. SECURITY

#### 1a. Command Injection in Shell Execution (HIGH)

`LocalWorkspaceService+Shell.swift:19` passes user-influenced strings directly to `/bin/zsh -l -c`:

```swift
process.arguments = ["-l", "-c", command]
```

Callers construct commands via string interpolation:

- `LocalWorkspaceService+Git.swift:12` — `cloneRepo` interpolates `url`, `name`, `branch`:
  ```swift
  "git clone --branch \(branch) --single-branch \(url) \(dest.path)"
  ```
- `LocalWorkspaceService+Git.swift:25` — `gitCommit` escapes single quotes but the escaping is insufficient for all injection vectors:
  ```swift
  let escaped = message.replacingOccurrences(of: "'", with: "'\\''")
  "git commit -m '\(escaped)' --allow-empty-message"
  ```
- `LocalWorkspaceService+Git.swift:53` — `gitRestore` interpolates `commitHash`:
  ```swift
  "git checkout \(commitHash) -- ."
  ```

If any of these values come from untrusted input (e.g., user-provided project names, AI-generated content), shell metacharacters could be injected.

**Recommendation:** Use `Process` with explicit argument arrays instead of shell string interpolation, or rigorously validate/sanitize all interpolated values.

#### 1b. WebView File Access (MEDIUM)

`WebPreview.swift:98` enables file access from file URLs:

```swift
config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
```

This allows JavaScript in loaded HTML files to read other local files. Since Forge renders AI-generated HTML, a malicious AI response could include JavaScript that reads local files.

**Recommendation:** Consider sandboxing the WKWebView more tightly, or using `WKContentRuleList` to restrict file:// access patterns.

#### 1c. API Keys in Memory (LOW)

API keys are loaded from Keychain and held in plain strings during API calls (`ClaudeService.swift:12`, `GroqService.swift:12`). This is standard practice but worth noting — keys exist in process memory during the entire streaming call.

---

### 2. BUGS & CORRECTNESS

#### 2a. PulsingDots Timer Leak

`ChatTabContent.swift:184` creates a `Timer.scheduledTimer` in `onAppear` but never invalidates it:

```swift
.onAppear {
    Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
        withAnimation(.easeInOut(duration: 0.3)) {
            active = (active + 1) % 3
        }
    }
}
```

Every time the view appears, a new timer is created. If the view is removed and re-added, timers accumulate.

**Fix:** Store the timer reference and invalidate it in `onDisappear`, or use a SwiftUI `TimelineView` instead.

#### 2b. Line Number / Editor Scroll Desync

`CodeEditorView.swift:83-104` — The line number gutter and the code editor are in separate `ScrollView` containers. They won't scroll in sync — the user can scroll the code while line numbers stay still, and vice versa.

**Fix:** Unify into a single scroll container, or use scroll position coordination.

#### 2c. ChatViewModel Message Index Safety

`ChatViewModel.swift:62` mutates `messages[assistantIndex]` during streaming, but `assistantIndex` is computed once at creation time. If messages are modified from another path (e.g., `resetForProject` called concurrently), the index could become stale or out of bounds.

**Mitigation:** The `@MainActor` annotation helps, but a concurrent `resetForProject()` call (from `onChange` on project switch) during active streaming could still cause issues.

#### 2d. Silent JSON Serialization Failure

Both `ClaudeService.swift:57` and `GroqService.swift:59`:

```swift
return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
```

If serialization fails, an empty `Data()` is sent as the request body, which will produce a confusing API error rather than a clear failure.

#### 2e. `InfiniteGrid` Performance

`GridBackground.swift:9-18` — `InfiniteGrid` creates a 10,000×10,000 point canvas. Though it appears unused (only `GridBackground` is referenced), this would be very expensive if instantiated.

---

### 3. ARCHITECTURE & CODE QUALITY

#### 3a. Dual Observation Patterns

The codebase mixes `ObservableObject` / `@Published` / `@ObservedObject` (old pattern) with `@Observable` / `@MainActor` (new pattern):

- `AppState` → `ObservableObject` + `@Published`
- `ChatViewModel` → `@Observable` (Swift Observation)
- `CodeViewModel` → `ObservableObject` + `@Published`
- `DesignViewModel` → `ObservableObject` + `@Published`
- `LocalWorkspaceService` → `@Observable`

This works but creates inconsistency. `ChatViewModel` uses `@Observable` but is consumed via `var chatViewModel` (not `@State` or `@Bindable`), which may cause update issues in some SwiftUI contexts.

#### 3b. AppState God Object

`AppState` (~237 lines) holds nearly all app state: navigation, auth, projects, pages, files, AI provider selection, preview URLs, services, and view models. This works at current scale but will become a bottleneck as the app grows.

#### 3c. Duplicate Icon/Color Mappings

File type → icon and file type → color mappings are duplicated in:
- `ProjectFile.swift` (FileTreeNode.icon)
- `CodeEditorView.swift` (iconForFile, colorForFile)
- `FileTreeView.swift` (iconColor)
- `CodeFileRow.swift` (icon, iconColor)

These could be consolidated into one utility.

#### 3d. Unused Code

- `ToolCard` view (`ToolCard.swift`) — defined but never used; replaced by inline card views
- `CollapsedToolButton` — has empty `action: {}`, buttons do nothing when collapsed
- `BrowserChrome` — defined but never used (WebPreview renders directly)
- `InfiniteGrid` — defined but only `GridBackground` is used
- `ProjectFile` struct — defined but never used (CodeViewModel uses `FileTreeNode` directly)
- `ToolbarButton` typealias (`TopbarComponents.swift:110`) — legacy alias, should be removed

#### 3e. `@unchecked Sendable` Usage

Both `ClaudeService` and `GroqService` are marked `@unchecked Sendable`. They are stateless (no mutable properties), so they are actually safely Sendable, but the `@unchecked` suppresses compiler verification.

---

### 4. UI/UX

#### 4a. `loadPages` Excludes Non-Root HTML

`LocalWorkspaceService+Preview.swift:175`:

```swift
if !file.path.contains("/"), file.path != "index.html" { return nil }
```

This filters out any HTML file at the root level that isn't `index.html`. Files like `about.html`, `contact.html` at root level won't appear in pages. This seems intentional for the "Build Site" flow but may confuse users who manually add HTML files.

#### 4b. Build Site Only Saves to `index.html`

`ChatViewModel.swift:116`:

```swift
try appState.workspace.writeFile(project: projectName, path: "index.html", content: html)
```

When the AI generates multiple pages (as requested by "Build Site"), only the first HTML block is extracted and saved as `index.html`. The multi-page generation from `BuildSiteSheet` sends a prompt requesting multiple files, but the response handling only captures the first `\`\`\`html` block.

#### 4c. No Error Display for Failed Saves

`ChatViewModel.swift:131-134` — File write errors are only logged in DEBUG builds, not shown to the user. Same for project creation errors at line 162.

---

### 5. DEPENDENCIES

- **Firebase** (Auth, Core) — used for Google Sign-In
- **WebKit** — WKWebView for HTML preview
- **Security** — Keychain access for API keys
- **UserNotifications** — macOS notifications (permission requested but `notify()` never called)
- **AuthenticationServices** — ASWebAuthenticationSession for OAuth

---

## Summary

| Category | Count | Severity |
|----------|-------|----------|
| Security | 3 | 1 High, 1 Medium, 1 Low |
| Bugs | 5 | 2 Medium, 3 Low |
| Architecture | 5 | All informational |
| UI/UX | 3 | All informational |

The codebase is clean, well-organized, and follows good SwiftUI patterns. The main actionable items are:

1. **Fix command injection** in shell execution (use Process argument arrays)
2. **Fix PulsingDots timer leak**
3. **Fix multi-page save** — handle multiple HTML files from AI responses
4. **Consolidate** file icon/color mappings
5. **Remove** unused types (ToolCard, BrowserChrome, InfiniteGrid, ProjectFile, ToolbarButton alias)
