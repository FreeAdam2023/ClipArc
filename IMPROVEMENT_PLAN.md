# ClipArc 代码质量改进计划

## 概述

本计划分三个阶段改进 ClipArc 代码质量：
1. **阶段一**：调试日志清理 + 错误处理改进 ✅ 已完成
2. **阶段二**：视图组件重构 + 常量提取 ✅ 已完成
3. **阶段三**：测试覆盖率提升 ✅ 已完成

**完成日期**: 2026-01-23

---

## 阶段一：调试日志与错误处理 ✅

### 1.1 创建日志工具

**新建文件**: `ClipArc/Core/Services/Logger.swift`

```swift
import Foundation

/// Centralized logging utility that only outputs in DEBUG builds
enum Logger {
    /// Log a debug message with source file information
    static func debug(_ message: String, file: String = #file, function: String = #function) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        print("[\(fileName)] \(message)")
        #endif
    }

    /// Log an error message with source file information
    static func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        if let error = error {
            print("[\(fileName)] ERROR: \(message) - \(error.localizedDescription)")
        } else {
            print("[\(fileName)] ERROR: \(message)")
        }
        #endif
    }
}
```

### 1.2 替换 57 个 print 语句 ✅

| 文件 | print 数量 | 状态 |
|------|-----------|------|
| `URLMetadataService.swift` | 15 | ✅ 已替换 |
| `PasteService.swift` | 15 | ✅ 已替换 |
| `HotkeyManager.swift` | 9 | ✅ 已替换 |
| `AppState.swift` | 6 | ✅ 已替换 |
| `ClipboardMonitor.swift` | 5 | ✅ 已替换 |
| `FloatingPanelController.swift` | 5 | ✅ 已替换 |
| `ClipboardStore.swift` | 2 | ✅ 已替换 |
| `PermissionsManager.swift` | 1 | ✅ 已替换 |
| `AuthManager.swift` | 1 | ✅ 已替换 |
| `AppDelegate.swift` | 1 | ✅ 已替换 |

### 1.3 改进错误处理 ✅

**ClipboardStore.swift** - 9 个 try? 转换为 do-catch 带 Logger.error:

```swift
// 示例: delete 方法
func delete(_ item: ClipboardItem) {
    modelContext.delete(item)
    do {
        try modelContext.save()
    } catch {
        Logger.error("Failed to save after delete", error: error)
    }
}

// 示例: clear 方法
func clear() {
    let fetchDescriptor = FetchDescriptor<ClipboardItem>()
    do {
        let items = try modelContext.fetch(fetchDescriptor)
        for item in items {
            modelContext.delete(item)
        }
        try modelContext.save()
    } catch {
        Logger.error("Failed to clear clipboard store", error: error)
    }
}

// 示例: fetchAll 方法
func fetchAll() -> [ClipboardItem] {
    var descriptor = FetchDescriptor<ClipboardItem>(
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    descriptor.fetchLimit = effectiveLimit
    do {
        return try modelContext.fetch(descriptor)
    } catch {
        Logger.error("Failed to fetch clipboard items", error: error)
        return []
    }
}
```

---

## 阶段二：视图重构与常量提取 ✅

### 2.1 创建常量文件 ✅

**新建文件**: `ClipArc/Core/Constants/UIConstants.swift`

```swift
import Foundation

/// UI layout constants for consistent spacing and sizing across the app
enum UIConstants {
    // MARK: - Panel
    static let panelHorizontalPadding: CGFloat = 16
    static let panelTopPadding: CGFloat = 12
    static let panelBottomPadding: CGFloat = 8
    static let cardSpacing: CGFloat = 16
    static let searchBarWidth: CGFloat = 200

    // MARK: - Card
    static let cardWidth: CGFloat = 260
    static let cardHeight: CGFloat = 240
    static let cardCornerRadius: CGFloat = 16
    static let selectedBorderWidth: CGFloat = 2.5
    static let cardHorizontalPadding: CGFloat = 12
    static let cardVerticalPadding: CGFloat = 12

    // MARK: - Image Preview
    static let imagePreviewMaxWidth: CGFloat = 220
    static let imagePreviewMaxHeight: CGFloat = 150
    static let thumbnailWidth: CGFloat = 220
    static let thumbnailHeight: CGFloat = 130

    // MARK: - Settings Window
    static let settingsWindowWidth: CGFloat = 500
    static let settingsWindowHeight: CGFloat = 520
    static let avatarSize: CGFloat = 80

    // MARK: - Onboarding Window
    static let onboardingWindowWidth: CGFloat = 500
    static let onboardingWindowHeight: CGFloat = 600

    // MARK: - Common Spacing
    static let smallSpacing: CGFloat = 4
    static let mediumSpacing: CGFloat = 8
    static let largeSpacing: CGFloat = 16
    static let extraLargeSpacing: CGFloat = 24

    // MARK: - Corner Radius
    static let smallCornerRadius: CGFloat = 6
    static let mediumCornerRadius: CGFloat = 8
    static let largeCornerRadius: CGFloat = 12
}

/// Timing constants for animations and delays
enum TimingConstants {
    static let clipboardPollingInterval: TimeInterval = 0.5
    static let defaultPasteDelay: TimeInterval = 0.3
    static let appDeactivationDelay: TimeInterval = 0.05
    static let pasteDelay: TimeInterval = 0.35
    static let keyEventDelayMicroseconds: UInt32 = 10000
    static let shortAnimationDuration: TimeInterval = 0.15
    static let mediumAnimationDuration: TimeInterval = 0.2
    static let longAnimationDuration: TimeInterval = 0.35
}
```

### 2.2 重构 FloatingPanelController.swift ✅

**改进前**: 1,257 行
**改进后**: 440 行 (65% 减少)

#### 提取的组件文件

```
ClipArc/UI/Panel/
├── FloatingPanelController.swift  (440 行, 原 1,257 行)
├── ClipboardCardView.swift        (新建, ~350 行)
├── FileThumbnailView.swift        (新建, ~150 行)
└── PanelComponents.swift          (新建, ~180 行)
    ├── CategoryTab
    ├── HorizontalEmptyStateView
    ├── UpgradePromptCard
    └── VisualEffectView
```

#### ClipboardCardView.swift 结构

```swift
// 主卡片视图
struct ClipboardCardView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isSelectionMode: Bool
    let isItemSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onToggleSelection: () -> Void
    // ... 实现
}

// 内容预览组件
private struct URLContentPreview: View { ... }
private struct CodeContentPreview: View { ... }
private struct ColorContentPreview: View { ... }
private struct FileContentPreview: View { ... }
private struct MultipleFilesPreview: View { ... }
private struct ImageContentPreview: View { ... }
private struct TextContentPreview: View { ... }
```

### 2.3 SettingsView.swift 和 OnboardingView.swift

这些文件已经具有良好的组件结构，无需进一步拆分：

**SettingsView.swift** (737 行) - 已包含独立视图:
- GeneralSettingsView
- AccountSettingsView
- SubscriptionSettingsView
- AboutView

**OnboardingView.swift** (711 行) - 已包含独立视图:
- WelcomeStepView
- PermissionsStepView
- LoginStepView
- SubscriptionStepView
- CompleteStepView

---

## 阶段三：测试覆盖率提升 ✅

### 3.1 测试基础设施 ✅

**新建文件**: `ClipArcTests/Mocks/MockURLSession.swift`

```swift
class MockURLSession: @unchecked Sendable {
    var data: Data?
    var response: URLResponse?
    var error: Error?
    var lastRequest: URLRequest?
    var requestCount = 0

    func data(for request: URLRequest) async throws -> (Data, URLResponse) { ... }
    func setHTMLResponse(_ html: String, statusCode: Int = 200) { ... }
    func setJSONResponse(_ json: String, statusCode: Int = 200) { ... }
    func setError(_ error: Error) { ... }
    func reset() { ... }
}
```

**新建文件**: `ClipArcTests/Mocks/MockUserDefaults.swift`

```swift
class MockUserDefaults: UserDefaults {
    private var storage: [String: Any] = [:]

    override func object(forKey defaultName: String) -> Any? { ... }
    override func set(_ value: Any?, forKey defaultName: String) { ... }
    override func removeObject(forKey defaultName: String) { ... }
    // ... 其他重写方法
    func reset() { ... }
    func allKeys() -> [String] { ... }
}
```

### 3.2 新增测试文件 ✅

| 测试文件 | 测试数量 | 覆盖内容 |
|----------|---------|---------|
| `URLMetadataServiceTests.swift` | 10 | URL 验证、标题提取、缓存、特殊字符 |
| `AppSettingsTests.swift` | 10 | 历史限制、外观设置、声音设置、重置 |
| `AppRatingManagerTests.swift` | 8 | 操作追踪、提示逻辑、用户响应、重置 |
| `LocalizationManagerTests.swift` | 10 | 语言切换、显示名称、原始值、本地化字符串 |
| `DateRelativeFormatTests.swift` | 10 | 各时间区间格式化、边界情况、一致性 |

### 3.3 测试文件结构

```
ClipArcTests/
├── Mocks/
│   ├── MockURLSession.swift       (新建)
│   └── MockUserDefaults.swift     (新建)
├── URLMetadataServiceTests.swift  (新建)
├── AppSettingsTests.swift         (新建)
├── AppRatingManagerTests.swift    (新建)
├── LocalizationManagerTests.swift (新建)
├── DateRelativeFormatTests.swift  (新建)
├── ClipboardItemTests.swift       (已存在)
├── ClipboardStoreTests.swift      (已存在)
├── SearchEngineTests.swift        (已存在)
├── StringFuzzyMatchTests.swift    (已存在)
├── AuthManagerTests.swift         (已存在)
└── SubscriptionManagerTests.swift (已存在)
```

---

## 验证命令

```bash
# 构建验证
xcodebuild -scheme ClipArc -configuration Debug -destination 'generic/platform=macOS' build

# 测试验证
xcodebuild test -scheme ClipArc -destination 'platform=macOS'

# Release 构建 (验证无 DEBUG 输出)
xcodebuild -scheme ClipArc -configuration Release -destination 'generic/platform=macOS' build
```

---

## 最终成果

| 指标 | 改进前 | 改进后 |
|------|-------|-------|
| print 语句 | 57 | 0 (Release) |
| try? 无日志 | 19 | 10 (仅数据解析) |
| FloatingPanelController 行数 | 1,257 | 440 |
| 新增组件文件 | 0 | 4 |
| 新增测试文件 | 0 | 7 (含 2 个 Mock) |
| 测试文件总行数 | ~800 | 1,284 |

**构建状态**: ✅ BUILD SUCCEEDED
