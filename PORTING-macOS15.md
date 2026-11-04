# macOS 15 版本：维护说明

本仓库是 [robbietilton/Compositor](https://github.com/robbietilton/Compositor) 的个人 fork，在上游基础上做三件事：

1. 让 app 能在 **macOS 15** 上运行（上游要求 macOS 26）
2. 带 **简体中文** 界面
3. 用 GitHub Actions 自动构建 **arm64** 包并发布 Release

基线是上游 `1.6.3`（commit `7f703b4`）。改动相对上游很小，目的是每次跟进上游时合并成本最低。

---

## 1. 与上游同步

远端：

```
origin    git@github.com:x2358473/Compositor.git
upstream  https://github.com/robbietilton/Compositor.git   （push 已设为 no_push，防止误推）
```

日常流程：

```bash
git fetch upstream
git log --oneline HEAD..upstream/main        # 无输出 = 上游没有新东西

git merge upstream/main                      # 冲突通常只落在下面「改动清单」里的几个文件
git push origin main                         # CI 自动构建，但不发 Release
```

如果合并后构建失败，**不要猜**，看 `ci-log` 分支：

```
https://raw.githubusercontent.com/x2358473/Compositor/ci-log/build-errors.txt
https://raw.githubusercontent.com/x2358473/Compositor/ci-log/build-log-full.txt
```

发版（版本号由上游的 `MARKETING_VERSION` 决定，tag 加 `-macos15` 后缀）：

```bash
git tag -a v1.6.4-macos15 -m "Compositor 1.6.4 for macOS 15 (Apple silicon)"
git push origin v1.6.4-macos15
```

---

## 2. 构建与发布

工作流：`.github/workflows/build-macos15.yml`

- **触发**：push 到 `main`、push `v*` tag、手动 `workflow_dispatch`
- **Runner**：`macos-26`，`Select Xcode` 步骤自动取 runner 上最新的一版
- **只出 arm64**，Release 配置
- **部署目标**：命令行传 `MACOSX_DEPLOYMENT_TARGET=15.0`，**不写进 pbxproj**（这是减少上游合并冲突的关键）
- **签名**：构建时 `CODE_SIGNING_ALLOWED=NO`，之后手动
  `codesign --force --deep --sign - --options runtime --entitlements Config/Compositor.entitlements`
- **校验**：`vtool -show-build` 必须出现 `minos 15.0`；`codesign -d --entitlements` 必须还有 `app-sandbox`。两者任一不满足就让构建失败
- **产物**：`Compositor-<version>-macOS15-arm64.zip` 和 `.dmg`；artifact 名同样带版本号
- **Release**：只有 push `v*` tag 才创建，标题 `Compositor <version> for macOS 15 (Apple silicon)`

> 上游自带的 `verify.yml` 仍会在每次 push 时运行（macos-26 + 部署目标 26 + 跑单测），与本工作流互不影响。本工作流只构建，不跑测试。

---

## 3. 改动清单（每处为什么）

相对上游 `7f703b4`，共 10 个文件。改 macOS 26 专属 API 的方式统一是 `if #available(macOS 26.0, *)`，15 上走降级分支。

| 文件 | 改动 | 原因 |
|---|---|---|
| `.github/workflows/build-macos15.yml` | 新增 | 构建、签名、打包、发布 |
| `Compositor/ContentView.swift` | 工具栏里两种 `ToolbarSpacer` 换成 `ToolbarItem { Color.clear ... }` 与 `ToolbarItem { Spacer() }`；去掉 `.sharedBackgroundVisibility(.hidden)`；tab 条目抽成 `projectTabStripItem(_:)` | 两个 API 都是 macOS 26。没用 `if #available` 包，是因为 `ToolbarContentBuilder` 里做条件分支容易出类型问题，而普通 spacer item 在 26 上的布局几乎一样 |
| `Compositor/UI/BlendModePicker.swift` | `button.borderShape = .capsule` 包 `#available` | `NSButton.borderShape` 是 macOS 26 |
| `Compositor/UI/TypeControls.swift` | 同上 | 同上 |
| `Compositor/UI/LayerSearchControls.swift` | `.labelReservedIconWidth(16)` 换成 `.reservedToggleIconWidth(16)`，文件末尾加 `@ViewBuilder` 扩展 | `labelReservedIconWidth` 是 macOS 26 |
| `Compositor/IO/RawImporter.swift` | 3 处 `isHighlightRecoverySupported/Enabled` 包 `#available` | `CIRAWFilter` 的高光恢复是 macOS 26；15 上该开关自动置灰 |
| `Compositor/UI/IndicatorlessScrollView.swift` | 给 `Container` 补一个空的 `deinit` 并标 `@_optimize(none)` | **Swift 6.3.3 编译器 bug**，见下节 |
| `Config/Info.plist` | `SUEnableAutomaticChecks` 改 `false`；`SUFeedURL` 改指向本仓库 `macos15` 分支（该分支暂无 appcast，等于不提供更新） | 官方 feed 只发 macOS 26 包，自动更新会把 app 换成跑不起来的版本 |
| `Config/Compositor.entitlements` | 加 `com.apple.security.cs.disable-library-validation` | ad-hoc 签名后 Sparkle 框架才能加载 |
| `Compositor/Resources/Localizable.xcstrings` | 新增，1400 条简中翻译 | 见「汉化」一节 |
| `Compositor.xcodeproj/project.pbxproj` | `knownRegions` 加 `"zh-Hans"` | 让 String Catalog 生成中文资源 |

### 为什么必须用 Xcode 26 编译，而不是 Xcode 16

项目 `pbxproj` 里有：

```
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
SWIFT_APPROACHABLE_CONCURRENCY = YES
```

这是 Swift 6.2（Xcode 26）才生效的设置，代码里有大量类型依赖「默认 MainActor 隔离」而没写 `@MainActor`。用 Xcode 16 编译会报几十处并发错误——这正是 `e:\gitea\compositor-15` 那个 fork 被迫补一堆 `@MainActor` 的原因。

所以路线固定为：**macOS 26 SDK + 最新 Xcode 编译，只把部署目标降到 15**。好处是任何漏掉的 26-only API 都会在编译期报错，不会静默出坏包。

### 已知的编译器崩溃

部署目标 15 + Swift 6.3.3 时，优化器会在下面这个位置崩溃（日志里只有 `Failed frontend command` + 一堆 `swift-frontend` 栈，没有 `error:`）：

```
While running pass "EarlyPerfInliner" on SILFunction
  "@$s10Compositor23IndicatorlessScrollViewV9ContainerCfD"
  for 'deinit' (at .../UI/IndicatorlessScrollView.swift:19:17)
```

`@_optimize(none)` 不能加在类上，所以改成显式声明那个自动合成的空 `deinit` 并单独标注。上游若在同一个类里加代码，合并时留意这一处。

---

## 4. 已知限制

- **只出 arm64**，Intel 未验证（上游本身也只声明 Apple Silicon）
- **没有开发者签名/公证**，首次打开需右键 → 打开，或
  `xattr -dr com.apple.quarantine /Applications/Compositor.app`
- **没有更新通道**：Sparkle 自动检查已关，也不提供自己的 appcast
- **不跑单测**，CI 只验证能构建、部署目标正确、签名带 sandbox entitlement
- 语言**跟随系统**，没有应用内切换（要加的话参见下一节末尾）

---

## 5. 汉化

只有一个文件：`Compositor/Resources/Localizable.xcstrings`。

生效原理：SwiftUI 的 `Text("…")`、`Button("…")`、`Label("…")`、`.help("…")`、`.accessibilityLabel("…")` 参数都是 `LocalizedStringKey`，只要 catalog 里有对应条目就显示中文，**不用改源码**。资源文件放 `Compositor/Resources/` 会被自动纳入构建（工程用的是 `PBXFileSystemSynchronizedRootGroup`），不需要改 build phase。

当前覆盖：上游 1.6.3 源码里 550 个唯一字符串 key，覆盖 505 个（约 92%）。缺口是 41 条带插值的（`\(count) layers` 这类，catalog key 是 `%lld layers` 格式）和 4 个纯符号。

**仍然显示英文的地方**（设计内保留）：

- 字符串拼接，如 `"Align " + alignment.rawValue.lowercased()`
- `String` 类型的文案：`session.error`、`NSAlert` 内容、`NSMenuItem` 标题
- 上述 41 条插值提示语

补翻译时直接往 xcstrings 里加条目即可，格式：

```json
    "Some English": {
      "extractionState": "manual",
      "localizations": {
        "zh-Hans": {
          "stringUnit": { "state": "translated", "value": "某段中文" }
        }
      }
    },
```

上游新增字符串没翻译时会自动回退英文，不影响构建。

如果以后要做**应用内语言切换**：`e:\gitea\compositor-15` 的 `Compositor/Resources/Localization.swift` 是现成实现（`L10n` + `AppLanguage` + 菜单），但它需要给 40 多个文件里的字符串补 `bundle:` 参数，会显著增加跟上游合并的成本——这也是那个 fork 一直追不上新版本的原因，取舍时注意。

---

## 6. 排障对照

| 现象 | 原因 / 处理 |
|---|---|
| `'xxx' is only available in macOS 26.0 or newer` | 上游新增了 26-only API。在调用处包 `if #available(macOS 26.0, *)`，并确认 15 上的降级行为可接受 |
| 日志只有 `Failed frontend command` 和 `swift-frontend` 栈 | 编译器崩溃（见第 3 节）。看 `build-log-full.txt` 里 `While running pass` 那一行定位文件和类型 |
| `actool` / `Localizable.xcstrings` 相关报错 | catalog JSON 格式问题。用 `python -c "import json,io;json.load(io.open(path,encoding='utf-8'))"` 本地校验 |
| `Sign the app` 失败 | 先看是不是内嵌 Sparkle 组件的问题；必要时拆成先签 framework 再签 app |
| `Verify the deployment target` 失败 | 说明命令行部署目标没生效，检查 `MACOSX_DEPLOYMENT_TARGET=15.0` 是否还在 build 命令里 |
| 用户下载后提示「已损坏」 | 未公证，属预期。`xattr -dr com.apple.quarantine` 或右键打开 |

失败时除了 `ci-log` 分支，artifact 的**名字**也会带上第一条错误（workflow 里 `LOG_NAME` 那段），因为公开仓库的 job 日志和 artifact 内容都需要 token 才能读。
