# ClipArc 分发指南

本文档说明如何构建和分发 ClipArc 的两个版本：App Store 版本和独立分发版本。

---

## 双轨分发架构

| 版本 | 编译标志 | Direct Paste | 沙盒 | 支付 |
|------|---------|--------------|------|------|
| App Store | `APPSTORE` | ❌ 禁用 | ✅ 启用 | Apple IAP |
| 独立分发 | `DIRECT` | ✅ 可用 | ❌ 禁用 | Paddle |

---

## 第一部分：App Store 版本

### 1.1 Xcode 配置

#### 创建 Build Configuration

1. 打开 Xcode → 选择项目 → **PROJECT** → **ClipArc** → **Info**
2. 在 **Configurations** 区域点击 **+**
3. 选择 **Duplicate "Release" Configuration**
4. 命名为 `Release-AppStore`

#### 设置编译标志

1. 选择 **Build Settings** 标签
2. 搜索 `Active Compilation Conditions`
3. 在 `Release-AppStore` 中设置：`APPSTORE`

#### 设置 Entitlements

1. 搜索 `Code Signing Entitlements`
2. 确保 `Release-AppStore` 使用：`ClipArc/ClipArc.entitlements`

#### 创建 Scheme

1. **Product** → **Scheme** → **Manage Schemes...**
2. 选择 **ClipArc** → 齿轮图标 → **Duplicate**
3. 命名为 `ClipArc (App Store)`
4. 编辑 Scheme → **Archive** → Build Configuration 选 `Release-AppStore`

### 1.2 App Store 版本功能

App Store 版本（定义 `APPSTORE` 标志）：

- ✅ 剪贴板监控和历史记录
- ✅ 搜索和过滤
- ✅ 复制到剪贴板
- ✅ 显示 "Copied" Toast
- ✅ 订阅功能 (Apple IAP)
- ❌ Direct Paste (Cmd+V 模拟) - 已禁用
- ❌ Accessibility 权限请求 - 已移除
- ❌ Direct Paste 设置项 - 已隐藏

### 1.3 构建和提交

```bash
# 构建 Archive
xcodebuild -scheme "ClipArc (App Store)" \
  -configuration Release-AppStore \
  -destination 'generic/platform=macOS' \
  archive -archivePath ./build/ClipArc-AppStore.xcarchive

# 或者在 Xcode 中：
# Product → Archive (确保选择 "ClipArc (App Store)" scheme)
```

### 1.4 审核注意事项

App Store 版本已移除所有 Accessibility API 调用：
- `AXIsProcessTrusted()` - 仅在非 APPSTORE 版本编译
- `CGEvent` 键盘模拟 - 仅在非 APPSTORE 版本编译
- 相关 UI 组件 - 仅在非 APPSTORE 版本编译

---

## 第二部分：独立分发版本

### 2.1 Xcode 配置

#### 创建 Build Configuration

1. 在 **Configurations** 区域点击 **+**
2. 选择 **Duplicate "Release" Configuration**
3. 命名为 `Release-Direct`

#### 设置编译标志

1. 在 `Release-Direct` 中设置 Active Compilation Conditions：`DIRECT`

#### 设置 Entitlements

1. 搜索 `Code Signing Entitlements`
2. 在 `Release-Direct` 中设置：`ClipArc/ClipArc-Direct.entitlements`

注意：`ClipArc-Direct.entitlements` 禁用了沙盒 (`com.apple.security.app-sandbox = false`)

#### 创建 Scheme

1. 复制 Scheme，命名为 `ClipArc (Direct)`
2. **Archive** → Build Configuration 选 `Release-Direct`

### 2.2 独立版本功能

独立分发版本（定义 `DIRECT` 标志或不定义 `APPSTORE`）：

- ✅ 所有 App Store 版本功能
- ✅ Direct Paste (自动 Cmd+V)
- ✅ Accessibility 权限管理
- ✅ Friction Detection 引导
- ✅ Paddle 支付（需要集成）

### 2.3 代码签名和公证

独立分发必须进行公证，否则用户会看到 "无法验证开发者" 警告。

#### 构建

```bash
# 构建 Archive
xcodebuild -scheme "ClipArc (Direct)" \
  -configuration Release-Direct \
  -destination 'generic/platform=macOS' \
  archive -archivePath ./build/ClipArc-Direct.xcarchive
```

#### 导出

创建 `ExportOptions-Direct.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>6QZ78WYM7S</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

```bash
# 导出
xcodebuild -exportArchive \
  -archivePath ./build/ClipArc-Direct.xcarchive \
  -exportPath ./build/export \
  -exportOptionsPlist ExportOptions-Direct.plist
```

#### 创建 DMG

```bash
# 创建 DMG
hdiutil create -volname "ClipArc" \
  -srcfolder ./build/export/ClipArc.app \
  -ov -format UDZO \
  ./build/ClipArc.dmg
```

#### 公证

```bash
# 提交公证
xcrun notarytool submit ./build/ClipArc.dmg \
  --apple-id "your-apple-id@email.com" \
  --password "app-specific-password" \
  --team-id "6QZ78WYM7S" \
  --wait

# Staple（附加公证票据）
xcrun stapler staple ./build/ClipArc.dmg
```

### 2.4 支付集成 (Paddle)

#### 注册 Paddle 账户

1. 访问 https://paddle.com 注册账户
2. 完成商家验证
3. 创建产品：
   - ClipArc Pro Monthly - 订阅
   - ClipArc Pro Yearly - 订阅
   - ClipArc Lifetime - 一次性购买

#### 获取凭证

在 Paddle Dashboard 中获取：
- **Vendor ID**: 你的商家 ID
- **Product ID**: 每个产品的 ID
- **API Key**: 用于服务器端验证（可选）

#### 集成 Paddle SDK

1. 添加 CocoaPods 依赖：

```ruby
# Podfile
target 'ClipArc' do
  pod 'PaddleV4'
end
```

2. 创建 Paddle 管理器：

```swift
// PaddleManager.swift
#if !APPSTORE
import Paddle

@MainActor
class PaddleManager: NSObject, ObservableObject {
    static let shared = PaddleManager()

    // 替换为你的 Paddle 凭证
    private let vendorID = "YOUR_VENDOR_ID"
    private let productID = "YOUR_PRODUCT_ID"
    private let apiKey = "YOUR_API_KEY"

    private var paddle: Paddle?
    private var product: PADProduct?

    @Published var isLicensed = false
    @Published var licenseInfo: String?

    override init() {
        super.init()
        setupPaddle()
    }

    private func setupPaddle() {
        paddle = Paddle.sharedInstance(
            withVendorID: vendorID,
            apiKey: apiKey,
            productID: productID,
            configuration: nil,
            delegate: self
        )

        product = PADProduct(
            productID: productID,
            productType: .sdkProduct,
            configuration: nil
        )

        // 检查现有许可证
        product?.refresh { [weak self] (delta, error) in
            DispatchQueue.main.async {
                self?.updateLicenseStatus()
            }
        }
    }

    func showPurchaseUI() {
        guard let product = product else { return }
        paddle?.showProductAccessDialog(with: product)
    }

    func activateLicense(email: String, licenseCode: String) {
        product?.activateEmail(email, license: licenseCode) { [weak self] activated, error in
            DispatchQueue.main.async {
                if activated {
                    self?.updateLicenseStatus()
                } else if let error = error {
                    // 处理错误
                    print("Activation failed: \(error)")
                }
            }
        }
    }

    func deactivateLicense() {
        product?.deactivate { [weak self] deactivated, error in
            DispatchQueue.main.async {
                if deactivated {
                    self?.updateLicenseStatus()
                }
            }
        }
    }

    private func updateLicenseStatus() {
        isLicensed = product?.activated ?? false
        if let activation = product?.activationEmail {
            licenseInfo = activation
        }
    }
}

extension PaddleManager: PaddleDelegate {
    func canAutoActivate(_ product: PADProduct) -> Bool {
        return true
    }

    func productActivated(_ notification: Notification) {
        updateLicenseStatus()
    }

    func productDeactivated(_ notification: Notification) {
        updateLicenseStatus()
    }
}
#endif
```

3. 创建许可证 UI：

```swift
// LicenseView.swift
#if !APPSTORE
struct LicenseView: View {
    @ObservedObject var paddleManager = PaddleManager.shared
    @State private var email = ""
    @State private var licenseCode = ""

    var body: some View {
        VStack(spacing: 20) {
            if paddleManager.isLicensed {
                // 已激活状态
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text("License Activated")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let info = paddleManager.licenseInfo {
                        Text(info)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Deactivate License") {
                        paddleManager.deactivateLicense()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // 未激活状态
                VStack(spacing: 16) {
                    Text("Activate ClipArc Pro")
                        .font(.title2)
                        .fontWeight(.semibold)

                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)

                    TextField("License Code", text: $licenseCode)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 12) {
                        Button("Activate") {
                            paddleManager.activateLicense(
                                email: email,
                                licenseCode: licenseCode
                            )
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Buy License") {
                            paddleManager.showPurchaseUI()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: 300)
            }
        }
        .padding()
    }
}
#endif
```

### 2.5 自动更新 (Sparkle)

#### 添加依赖

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
]
```

#### 配置 Sparkle

1. 在 Info.plist 添加：

```xml
<key>SUFeedURL</key>
<string>https://yourdomain.com/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_ED_KEY</string>
```

2. 生成签名密钥：

```bash
./bin/generate_keys
# 保存私钥，公钥添加到 Info.plist
```

3. 创建 appcast.xml：

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>ClipArc Updates</title>
    <item>
      <title>Version 1.0.1</title>
      <sparkle:version>1.0.1</sparkle:version>
      <sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>
      <pubDate>Mon, 01 Jan 2026 00:00:00 +0000</pubDate>
      <enclosure
        url="https://yourdomain.com/releases/ClipArc-1.0.1.dmg"
        sparkle:edSignature="YOUR_SIGNATURE"
        length="12345678"
        type="application/octet-stream" />
    </item>
  </channel>
</rss>
```

4. 集成到应用：

```swift
// AppDelegate.swift
#if !APPSTORE
import Sparkle

// 添加属性
private var updaterController: SPUStandardUpdaterController?

// 在 applicationDidFinishLaunching 中
updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
)
#endif
```

---

## 第三部分：构建脚本

### 完整构建脚本

创建 `scripts/build.sh`：

```bash
#!/bin/bash

set -e

VERSION=$(cat VERSION || echo "1.0.0")
BUILD_DIR="./build"

# 清理
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 构建 App Store 版本
echo "Building App Store version..."
xcodebuild -scheme "ClipArc (App Store)" \
  -configuration Release-AppStore \
  -destination 'generic/platform=macOS' \
  archive -archivePath "$BUILD_DIR/ClipArc-AppStore.xcarchive"

# 构建独立版本
echo "Building Direct version..."
xcodebuild -scheme "ClipArc (Direct)" \
  -configuration Release-Direct \
  -destination 'generic/platform=macOS' \
  archive -archivePath "$BUILD_DIR/ClipArc-Direct.xcarchive"

# 导出独立版本
echo "Exporting Direct version..."
xcodebuild -exportArchive \
  -archivePath "$BUILD_DIR/ClipArc-Direct.xcarchive" \
  -exportPath "$BUILD_DIR/export" \
  -exportOptionsPlist ExportOptions-Direct.plist

# 创建 DMG
echo "Creating DMG..."
hdiutil create -volname "ClipArc" \
  -srcfolder "$BUILD_DIR/export/ClipArc.app" \
  -ov -format UDZO \
  "$BUILD_DIR/ClipArc-$VERSION.dmg"

echo "Build complete!"
echo "App Store archive: $BUILD_DIR/ClipArc-AppStore.xcarchive"
echo "Direct DMG: $BUILD_DIR/ClipArc-$VERSION.dmg"
```

### 公证脚本

创建 `scripts/notarize.sh`：

```bash
#!/bin/bash

set -e

DMG_PATH=$1
APPLE_ID="your-apple-id@email.com"
TEAM_ID="6QZ78WYM7S"

if [ -z "$DMG_PATH" ]; then
  echo "Usage: ./notarize.sh <path-to-dmg>"
  exit 1
fi

echo "Submitting for notarization..."
xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --password "@keychain:AC_PASSWORD" \
  --team-id "$TEAM_ID" \
  --wait

echo "Stapling..."
xcrun stapler staple "$DMG_PATH"

echo "Notarization complete!"
```

---

## 附录：条件编译参考

### 已修改的文件

| 文件 | 修改内容 |
|------|---------|
| `ClipArc-Direct.entitlements` | 独立版 entitlements（禁用沙盒） |
| `DirectPasteCapabilityManager.swift` | `#if APPSTORE` 条件编译 |
| `PasteService.swift` | `simulateCmdV()` 仅 Direct 版本 |
| `PasteActionCoordinator.swift` | 粘贴逻辑条件编译 |
| `FrictionDetector.swift` | 仅 Direct 版本 |
| `DirectPasteGuideView.swift` | 仅 Direct 版本 |
| `AccessibilitySetupView.swift` | 仅 Direct 版本 |
| `SettingsView.swift` | Direct Paste 设置行条件编译 |
| `AppDelegate.swift` | Direct Paste 初始化条件编译 |

### 条件编译使用方式

```swift
#if APPSTORE
// 仅 App Store 版本编译
#elseif DIRECT
// 仅独立分发版本编译
#else
// 默认（Debug 或未指定）
#endif

#if !APPSTORE
// 非 App Store 版本（包括 Direct 和 Debug）
#endif
```

---

*最后更新: 2026-02-02*
