# Example App — Agent Instructions

> `CLAUDE.md` is a symlink to this file. Always edit `AGENTS.md`.

## Purpose

The Example app is a demo/showcase for ListKit and Lists features. It is built with Tuist (not SPM) and lives outside the main package targets.

## Structure

```
Example/
├── Project.swift                        — Tuist project manifest
└── Sources/
    ├── AppDelegate.swift                — App lifecycle
    ├── SceneDelegate.swift              — Window setup with tab bar
    ├── ListKitExampleViewController.swift    — Raw ListKit API usage
    ├── DSLExampleViewController.swift        — GroupedList with SnapshotBuilder DSL
    ├── LiveExampleViewController.swift       — Real-time updates demo
    ├── GroupedListExampleViewController.swift — Multi-section grouped list
    ├── OutlineExampleViewController.swift    — Hierarchical expand/collapse
    ├── MixedExampleViewController.swift      — Mixed cell types
    ├── SwiftUIExampleViewController.swift    — SwiftUI wrappers hosted in UIKit
    ├── SwiftUIWrappersExampleView.swift      — Pure SwiftUI list views
    ├── ChatExampleView.swift                — Chat UI (SwiftUI + SimpleListView)
    ├── ChatShared.swift                     — Shared chat types, bubble view, scroll protocol
    ├── ChatInputBar.swift                   — Shared UIKit input bar
    ├── ListsChatExampleViewController.swift — Chat UI (UIKit + SimpleList + CellViewModel)
    └── ListKitChatExampleViewController.swift — Chat UI (UIKit + raw CollectionViewDiffableDataSource)
```

## Conventions

- Each example is a standalone view controller or SwiftUI view
- Examples should be self-contained — define their own ViewModels inline
- The `SceneDelegate` builds a tab bar with one tab per example
- To add a new example: create the VC/View, add a tab in `SceneDelegate`
- Open with `make open` (requires `make setup` first)

## Build

The Example app is part of the Tuist workspace, not the SPM package. It's built via Xcode, not `swift build`. Use `make open` to generate and open the workspace.
