# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClipArc is a native multi-platform Apple application built with Swift and SwiftUI. It targets iOS, macOS, and visionOS using a single codebase.

## Build Commands

```bash
# Build for macOS
xcodebuild -scheme ClipArc -configuration Debug -destination 'generic/platform=macOS'

# Build for iOS Simulator
xcodebuild -scheme ClipArc -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16'

# Build for visionOS
xcodebuild -scheme ClipArc -configuration Debug -destination 'generic/platform=visionOS'

# Clean build
xcodebuild clean -scheme ClipArc

# Run tests (when test targets exist)
xcodebuild test -scheme ClipArc -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or open `ClipArc.xcodeproj` in Xcode and use Cmd+B (build), Cmd+R (run), Cmd+U (test).

## Architecture

**Tech Stack:** Swift 5.0, SwiftUI, SwiftData (persistence)

**Source Files (ClipArc/):**
- `ClipArcApp.swift` - App entry point with `@main`, initializes SwiftData ModelContainer
- `ContentView.swift` - Main UI using NavigationSplitView with list/detail layout
- `Item.swift` - SwiftData model with `@Model` macro

**Data Flow:**
- SwiftData's `ModelContainer` is configured at app launch and passed via `.modelContainer()` modifier
- Views access data through `@Environment(\.modelContext)` and `@Query` property wrappers
- Models use `@Model` macro for automatic persistence

## Platform Considerations

- Uses `#if os(iOS)` conditionals for platform-specific UI (e.g., EditButton)
- NavigationSplitView provides adaptive layout across device sizes
- App Sandbox enabled on macOS with readonly file access
- Minimum deployment: iOS 26.1, macOS 26.1, visionOS 26.1
