# Forge App — Code Scan Report (v2)

**Date:** 2026-02-05
**Scope:** All 57 Swift files in `macos/Forge/`
**App:** Forge — AI-powered web design tool (macOS native, SwiftUI)
**Previous scan:** v1 (same date) — identified 16 findings across security, bugs, architecture, and UI/UX

---

## Changes Since Last Scan

The following issues from v1 have been **resolved**:

| # | Finding | Status |
|---|---------|--------|
| 1a | Command injection in shell execution | **Fixed** — `exec()` replaced with `run()` using Process argument arrays |
| 1b | WebView file access unconditional | **Fixed** — `allowFileAccessFromFileURLs` only when `localFileURL != nil` |
| 2a | PulsingDots timer leak | **Fixed** — timer stored in `@State`, invalidated in `onDisappear` |
| 2c | ChatViewModel message index safety | **Fixed** — uses `assistantId` (UUID) with `firstIndex(where:)` |
| 2d | Silent JSON serialization failure | **Fixed** — `buildRequestBody` now `throws` in both ClaudeService and GroqService |
| 2e | InfiniteGrid performance risk | **Fixed** — removed entirely |
| 3d | Unused code (6 items) | **Fixed** — removed ToolCard, BrowserChrome (emptied), InfiniteGrid, ProjectFile (kept FileTreeNode), ToolbarButton alias |
| 4b | Build Site only saves to index.html | **Fixed** — `extractAllHTML()` handles multiple files with filename detection |
| 4a | loadPages excludes non-root HTML | **Fixed** — all `.html` files now loaded |
| — | Glass-on-glass rendering (UI) | **Fixed** — removed nested `.glassEffect(.regular)`, use `glassFill` backgrounds |
| — | WindowAccessor conflict with glass | **Fixed** — removed WindowAccessor, use `.windowStyle(.plain)` |

---

## Architecture Overview

```
Forge/
├── App/          — ForgeApp entry, AppState (singleton), AppRouter, Topbar
├── Domains/
│   ├── AI/       — AIService protocol, Claude + Groq streaming, SSE parsing, Keychain
│   ├── Auth/     — Google OAuth → Firebase via ASWebAuthenticationSession
│   ├── Chat/     — ChatViewModel, message bubbles, floating chat, ChatTabContent
│   ├── Design/   — DesignView, BriefBuilder, DesignViewModel, StartProjectSheet
│   ├── Editor/   — CodeModeView, CodeEditorView, FileTreeView, CodeViewModel
│   ├── Preview/  — WKWebView HTML preview, VersionDots
│   ├── Projects/ — Project/Page domain models, formatters, filters
│   ├── Tools/    — ToolsPanel, NewProject/BuildSite/Settings cards
│   └── Workspace/— LocalWorkspaceService (files, git, shell, preview), sidebar views
└── Shared/       — HTTPClient, Theme, CommandBar
```

**Total:** ~3,500 lines across 57 files. Clean, focused codebase.

---

## Current Findings

### 1. SECURITY

#### 1a. API Keys in Memory (LOW)

API keys are loaded from Keychain and held in plain strings during API calls (`ClaudeService.swift:12`, `GroqService.swift:12`). Standard practice — keys exist in process memory during streaming calls. No action needed.

#### 1b. `which()` Fallback to `/usr/bin/env` (LOW)

`LocalWorkspaceService+Shell.swift:90` — if git/python3 isn't found in the three hardcoded paths, `which()` falls back to `/usr/bin/env`. When used with `run()`, this would attempt to execute `/usr/bin/env` with git arguments, which would silently fail or produce confusing errors rather than a clear "git not found" message.

**Impact:** Low — git/python3 are virtually always at one of the three checked paths on macOS.

#### 1c. AI-Generated HTML Rendered Without Sandboxing (LOW)

`WebPreview.swift` renders AI-generated HTML in a WKWebView with `.nonPersistent()` data store. When rendering inline HTML (no `localFileURL`), file access is correctly disabled. However, there's no Content Security Policy or JavaScript restriction — AI-generated code could make network requests (fetch, XMLHttpRequest) or load external resources.

**Impact:** Low — the AI generates code the user explicitly requested, and WebKit's process isolation provides baseline security.

---

### 2. BUGS & CORRECTNESS

#### 2a. CodeEditorView Line Number / Editor Scroll Desync (MEDIUM)

`CodeEditorView.swift:82-104` — The line number gutter and the code editor are in separate `ScrollView` containers. They won't scroll in sync — the user can scroll the code while line numbers stay still, and vice versa.

**Fix:** Unify into a single scroll container, or use `ScrollView` coordinate tracking to sync scroll positions.

#### 2b. `readDataToEndOfFile()` After `waitUntilExit()` Ordering (LOW)

`LocalWorkspaceService+Shell.swift:62-66` — The code calls `process.waitUntilExit()` before `pipe.fileHandleForReading.readDataToEndOfFile()`. For commands with large output, the pipe buffer can fill up, causing `waitUntilExit()` to block indefinitely (deadlock). The correct order is to read data first, then wait.

**Impact:** Low — most git/shell commands produce small output, but edge cases (large diffs, large `git log`) could hang.

#### 2c. CollapsedToolButton Does Nothing (LOW)

`ToolCard.swift:8` — `CollapsedToolButton`'s action is always `{}` (empty closure). When the tools panel is collapsed, the Build Site, Settings, and Chat buttons are decorative only — they don't expand the panel or trigger actions.

**Impact:** Low — users can click the expand button at the top. But the buttons misleadingly look interactive.

#### 2d. `DragGesture` Accumulates in ToolsPanel Divider (LOW)

`ToolsPanel.swift:83-89` — The drag gesture uses `value.translation.height` which is cumulative during a single drag. But `toolsHeight` is being set to `toolsHeight + translation`, meaning each `.onChanged` event adds the total translation so far (not the delta), causing the divider to jump unpredictably.

**Fix:** Track the starting height when drag begins and use `startHeight + translation.height`.

#### 2e. Error Logging Only in DEBUG (INFO)

Multiple files log errors only under `#if DEBUG`:
- `ChatViewModel.swift:137-139` — failed HTML save
- `ChatViewModel.swift:170-172` — failed project creation
- `StartProjectSheet.swift:145-147` — failed project creation

In release builds, these errors are silently swallowed. Users get no feedback when saves fail.

---

### 3. ARCHITECTURE & CODE QUALITY

#### 3a. Dual Observation Patterns (INFO)

The codebase mixes two observation patterns:
- **ObservableObject + @Published:** `AppState`, `CodeViewModel`, `DesignViewModel`
- **@Observable (Swift Observation):** `ChatViewModel`, `LocalWorkspaceService`

This works but creates inconsistency. `ChatViewModel` uses `@Observable` but is held as `var chatViewModel` in `AppState` (an `ObservableObject`). In most cases SwiftUI handles this correctly, but some edge cases may miss updates.

#### 3b. AppState God Object (INFO)

`AppState` (~237 lines) holds nearly all app state: navigation, auth, projects, pages, files, AI provider, preview URLs, services, and view models. Manageable at current scale (~3,500 LOC) but will become a bottleneck as the app grows. Consider extracting domain-specific state objects (e.g., `PreviewState`, `ProjectState`).

#### 3c. Duplicate Icon/Color Mappings (INFO)

File type → icon and file type → color mappings are duplicated across:
- `ProjectFile.swift` (FileTreeNode.icon) — extension → SF Symbol
- `CodeEditorView.swift` (iconForFile, colorForFile) — extension → SF Symbol + Color
- `FileTreeView.swift` (iconColor) — extension → Color
- `CodeFileRow.swift` (icon, iconColor) — extension → SF Symbol + Color

These four locations define the same mappings with slight variations. One shared utility would reduce drift.

#### 3d. `@unchecked Sendable` on AI Services (INFO)

Both `ClaudeService` and `GroqService` are `@unchecked Sendable`. They are stateless (only `let` properties), so they are genuinely Sendable. The `@unchecked` annotation suppresses compiler verification, which is acceptable here.

#### 3e. BrowserChrome.swift is Empty (INFO)

`BrowserChrome.swift` contains only a comment. It should either be deleted from the project or the file reference should be removed from the Xcode project to avoid confusion.

#### 3f. NotificationService `notify()` Never Called (INFO)

`NotificationService.swift` requests notification permissions on app launch, but `notify()` is never called anywhere in the codebase. Either use it (e.g., notify when generation completes while app is in background) or remove the permission request.

---

### 4. UI/UX

#### 4a. FloatingChatWindow Uses `.glassEffect(.regular)` (LOW)

`FloatingChatWindow.swift:82` applies `.glassEffect(.regular)` directly. This is correct for a floating overlay element (it's independent, not nested inside `GlassEffectContainer`), but it's the only component still using `.glassEffect()` directly, which may look inconsistent with the `glassFill` approach used elsewhere.

#### 4b. CodeModeView Preview Refresh Button Does Nothing (LOW)

`CodeModeView.swift:130-134` — The preview section's refresh button has `action: {}` (empty closure). It looks clickable but does nothing.

#### 4c. Close Button in CodeEditorView Tab Does Nothing (LOW)

`CodeEditorView.swift:42-48` — The tab close button ("xmark") has `action: {}`. It appears to be a close tab control but doesn't close the file.

---

### 5. DEPENDENCIES

- **Firebase** (Auth, Core) — Google Sign-In
- **WebKit** — WKWebView for HTML preview
- **Security** — Keychain for API keys
- **UserNotifications** — Permission requested but `notify()` never called
- **AuthenticationServices** — `ASWebAuthenticationSession` for OAuth

---

## Summary

| Category | Count | Severity |
|----------|-------|----------|
| Security | 3 | All Low |
| Bugs | 5 | 1 Medium, 4 Low/Info |
| Architecture | 6 | All informational |
| UI/UX | 3 | All Low |

### Resolved Since v1

- **Command injection** — fully resolved with Process argument arrays
- **Timer leak** — fixed with proper lifecycle management
- **Silent JSON failures** — both services now throw
- **Multi-page save** — new `extractAllHTML()` with filename detection
- **Glass-on-glass UI** — clean single-level glass with `glassFill` backgrounds
- **Unused code** — 6 dead types/aliases removed
- **WebView sandboxing** — conditional file access

### Also Resolved (v2 → v2.1)

- **Scroll desync** — CodeEditorView now uses a single unified ScrollView for line numbers and code
- **Drag gesture accumulation** — ToolsPanel tracks `dragStartHeight` on gesture start
- **Pipe read ordering** — `readDataToEndOfFile()` now called before `waitUntilExit()`
- **No-op buttons** — tab close, preview refresh, and collapsed tool buttons now functional
- **Duplicate icon/color mappings** — consolidated into `FileTypeAppearance` shared utility
- **Silent errors** — `#if DEBUG` print-only errors replaced with `appState.errorMessage`

### Remaining (informational only)

- 3a: Dual observation patterns (`@Observable` + `ObservableObject`)
- 3b: AppState god object — consider splitting as app grows
- 3d: `@unchecked Sendable` on AI services — acceptable (stateless)
- 3e: BrowserChrome.swift empty — delete file from Xcode project
- 3f: NotificationService `notify()` never called — use or remove permission request

### Verdict

All actionable items have been resolved. The codebase has zero critical, high, or medium-severity findings. What remains is purely informational — architectural notes for future scale. The app is ready for continued development on a solid, clean foundation.
