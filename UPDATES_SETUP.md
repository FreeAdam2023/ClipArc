# ClipArc 自动更新（Sparkle）上线手册

ClipArc 的直接分发版（Direct，从网站下载）内置 Sparkle 应用内自动更新。
代码已全部接好，只差**两样你自己的东西**：一对签名密钥、一个托管在网站上的 appcast。

> App Store 版（`AppStore` 配置）通过 `#if !APPSTORE` 完全不含 Sparkle，无需理会本文档。

---

## 一次性设置

### 1. 生成 EdDSA 签名密钥

Sparkle 的命令行工具随 SPM 依赖一起下载了，位置在 DerivedData 里。先找到它：

```bash
find ~/Library/Developer/Xcode/DerivedData -path '*/artifacts/sparkle/Sparkle/bin/generate_keys' 2>/dev/null | head -1
```

运行它生成密钥（私钥会存进你的 macOS 登录钥匙串，**不要提交到 git**）：

```bash
/path/to/bin/generate_keys
```

它会打印一个 **public key**（形如 `pfIShh...=`，44 个字符的 base64）。

### 2. 把公钥填进 Info.plist

打开 `ClipArc/Info.plist`，把占位公钥替换成上一步打印的真实公钥：

```xml
<key>SUPublicEDKey</key>
<string>把这里换成你的真实公钥</string>
```

（占位值是全 A 的假 key，能让 app 正常启动，但更新校验一定失败——必须替换。）

### 3. 确认 feed 地址

`Info.plist` 里已经写好：

```xml
<key>SUFeedURL</key>
<string>https://cliparc.net/download/appcast.xml</string>
```

如果你要换到别的地址/路径，改这里即可。它必须是 **HTTPS**。

---

## 每次发新版

### 1. 打包 Direct 版

用默认的 `ClipArc` scheme（= 全功能 Direct 版）Archive，导出为 **Developer ID** 签名并**公证（notarize）**的 `.app`，
再压成 `ClipArc-<版本>.zip`（或做成 `.dmg`）。

> 非沙盒 + hardened runtime 的 Direct 版，分发前必须 notarize，否则用户首次打开会被 Gatekeeper 拦。

记得在打包前提升版本号（`ClipArc` target 的 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION`）。

### 2. 给更新包签名并生成 appcast

Sparkle 的 `generate_appcast` 会扫描一个目录里的所有 zip/dmg，自动用钥匙串里的私钥签名并生成 `appcast.xml`：

```bash
# 找到工具
find ~/Library/Developer/Xcode/DerivedData -path '*/artifacts/sparkle/Sparkle/bin/generate_appcast' 2>/dev/null | head -1

# 把新版 zip 放进一个目录，例如 ./releases/，然后：
/path/to/bin/generate_appcast ./releases/
```

生成的 `./releases/appcast.xml` 里，每个版本条目会带上 `sparkle:edSignature`。

> 也可以手动逐个签名：`bin/sign_update ClipArc-x.y.z.zip`，再把签名填进 appcast。`generate_appcast` 更省事。

### 3. 上传到网站

把这两样放到网站，让它们能通过 HTTPS 访问：

- `appcast.xml` → `https://cliparc.net/download/appcast.xml`（与 `SUFeedURL` 一致）
- 更新包 zip/dmg → appcast 里 `<enclosure url="...">` 指向的地址

appcast 里每个版本的下载 URL 要指向你实际托管更新包的位置（可以是同一网站，或 GitHub Releases 的直链）。`generate_appcast` 默认用文件名生成相对/占位 URL，检查一下改成真实绝对 URL。

### 4. 验证

装一个**旧版本**，菜单栏点 **检查更新…**（或等自动检查），应能看到 Sparkle 弹出新版本并完成升级。

---

## 代码位置速查

| 作用 | 文件 |
|---|---|
| Sparkle 封装（启动/检查更新/自动检查开关） | `ClipArc/Core/Services/UpdaterService.swift` |
| feed URL / 公钥 / 自动检查配置 | `ClipArc/Info.plist`（`SU*` 键） |
| 菜单栏「检查更新…」入口 | `ClipArc/ClipArcApp.swift`（`#if !APPSTORE`） |
| 设置里「更新」区块（自动检查开关 + 手动检查） | `ClipArc/UI/Settings/SettingsView.swift`（`UpdatesSettingsRow`） |
| SPM 依赖声明 | `ClipArc.xcodeproj`（Sparkle 2.6+，实际解析到 2.9.x） |

## 参考

- Sparkle 官方文档：https://sparkle-project.org/documentation/
- 发布流程：https://sparkle-project.org/documentation/publishing/
