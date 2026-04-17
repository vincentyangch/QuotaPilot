# QuotaPilot Foundation Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first working QuotaPilot macOS app slice: an Xcode-backed menu bar app with a dashboard window, a desktop widget shell, shared quota models, and a tested recommendation engine driven by seeded data.

**Architecture:** Use `XcodeGen` to generate a native macOS SwiftUI app project with three targets: `QuotaPilotCore`, `QuotaPilot`, and `QuotaPilotWidgetExtension`. Keep provider integrations out of this slice and instead establish the permanent app shape with shared domain models, a deterministic recommendation engine, seeded preview data, and UI surfaces that consume the same core types.

**Tech Stack:** Swift 6.2, SwiftUI, WidgetKit, Observation, XcodeGen, XCTest, shell build script

---

### Task 1: Scaffold The Native macOS Project

**Files:**
- Create: `project.yml`
- Create: `Config/QuotaPilot-Info.plist`
- Create: `Config/QuotaPilotWidget-Info.plist`
- Create: `script/build_and_run.sh`
- Create: `.codex/environments/environment.toml`

- [ ] **Step 1: Create the XcodeGen project file**

```yaml
name: QuotaPilot
options:
  minimumXcodeGenVersion: 2.39.0
settings:
  base:
    SWIFT_VERSION: 6.0
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    PRODUCT_NAME: "$(TARGET_NAME)"
targets:
  QuotaPilotCore:
    type: framework
    platform: macOS
    sources:
      - path: Sources/QuotaPilotCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.vincentyangch.QuotaPilot.core
        GENERATE_INFOPLIST_FILE: YES
        CODE_SIGNING_ALLOWED: NO
  QuotaPilot:
    type: application
    platform: macOS
    sources:
      - path: Sources/QuotaPilotApp
    dependencies:
      - target: QuotaPilotCore
    info:
      path: Config/QuotaPilot-Info.plist
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.vincentyangch.QuotaPilot
        CODE_SIGNING_ALLOWED: NO
        ASSETCATALOG_COMPILER_APPICON_NAME: ""
  QuotaPilotWidgetExtension:
    type: app-extension
    platform: macOS
    sources:
      - path: Sources/QuotaPilotWidget
    dependencies:
      - target: QuotaPilotCore
    info:
      path: Config/QuotaPilotWidget-Info.plist
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.vincentyangch.QuotaPilot.widget
        CODE_SIGNING_ALLOWED: NO
  QuotaPilotTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests/QuotaPilotTests
    dependencies:
      - target: QuotaPilotCore
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        CODE_SIGNING_ALLOWED: NO
schemes:
  QuotaPilot:
    build:
      targets:
        QuotaPilotCore: all
        QuotaPilot: all
        QuotaPilotWidgetExtension: all
        QuotaPilotTests: [test]
    test:
      targets:
        - QuotaPilotTests
```

- [ ] **Step 2: Add the macOS app and widget Info.plists**

```xml
<!-- Config/QuotaPilot-Info.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>QuotaPilot</string>
  <key>CFBundleName</key>
  <string>QuotaPilot</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
</dict>
</plist>
```

```xml
<!-- Config/QuotaPilotWidget-Info.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
  </dict>
</dict>
</plist>
```

- [ ] **Step 3: Add the build/run entrypoint**

```bash
#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="QuotaPilot"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
PROJECT_FILE="$ROOT_DIR/QuotaPilot.xcodeproj"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodegen generate

xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$APP_NAME" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  build

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"com.vincentyangch.QuotaPilot\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
```

- [ ] **Step 4: Wire the Codex app Run button**

```toml
# THIS IS AUTOGENERATED. DO NOT EDIT MANUALLY
version = 1
name = "QuotaPilot"

[setup]
script = ""

[[actions]]
name = "Run"
icon = "run"
command = "./script/build_and_run.sh"
```

- [ ] **Step 5: Generate the project and verify the structure**

Run: `xcodegen generate`
Expected: `Generated project at /Users/flyingchickens/Projects/QuotaPilot/QuotaPilot.xcodeproj`

- [ ] **Step 6: Commit the project scaffold**

```bash
git add project.yml Config script .codex
git commit -m "chore: scaffold native macOS project"
```

### Task 2: Add The Shared Quota Domain And Recommendation Engine

**Files:**
- Create: `Sources/QuotaPilotCore/Models/QuotaProvider.swift`
- Create: `Sources/QuotaPilotCore/Models/UsageWindow.swift`
- Create: `Sources/QuotaPilotCore/Models/QuotaAccount.swift`
- Create: `Sources/QuotaPilotCore/Models/GlobalRules.swift`
- Create: `Sources/QuotaPilotCore/Models/RecommendationDecision.swift`
- Create: `Sources/QuotaPilotCore/Services/RecommendationEngine.swift`
- Create: `Sources/QuotaPilotCore/Services/DemoAccountRepository.swift`
- Test: `Tests/QuotaPilotTests/RecommendationEngineTests.swift`

- [ ] **Step 1: Write the failing tests for scoring and switching decisions**

```swift
import XCTest
@testable import QuotaPilotCore

final class RecommendationEngineTests: XCTestCase {
    func testPrefersAccountWithHigherCompositeScoreWhenCurrentDropsBelowThreshold() {
        let current = QuotaAccount.codex(
            label: "Codex A",
            remainingPercent: 12,
            resetHours: 4,
            priority: 20,
            isCurrent: true)
        let next = QuotaAccount.claude(
            label: "Claude B",
            remainingPercent: 64,
            resetHours: 2,
            priority: 80,
            isCurrent: false)

        let decision = RecommendationEngine().evaluate(
            accounts: [current, next],
            rules: .default)

        XCTAssertEqual(decision.recommendedAccountID, next.id)
        XCTAssertEqual(decision.action, .recommendSwitch)
    }

    func testKeepsCurrentAccountWhenNoAlternativeClearsMinimumAdvantage() {
        let current = QuotaAccount.codex(
            label: "Codex A",
            remainingPercent: 48,
            resetHours: 3,
            priority: 60,
            isCurrent: true)
        let next = QuotaAccount.codex(
            label: "Codex B",
            remainingPercent: 50,
            resetHours: 3,
            priority: 60,
            isCurrent: false)

        let decision = RecommendationEngine().evaluate(
            accounts: [current, next],
            rules: .default)

        XCTAssertEqual(decision.recommendedAccountID, current.id)
        XCTAssertEqual(decision.action, .stayCurrent)
    }
}
```

- [ ] **Step 2: Run the test target to verify it fails**

Run: `xcodegen generate && xcodebuild test -project QuotaPilot.xcodeproj -scheme QuotaPilot -derivedDataPath build/DerivedData -only-testing:QuotaPilotTests/RecommendationEngineTests`
Expected: FAIL with missing `QuotaAccount`, `RecommendationEngine`, and `GlobalRules` symbols

- [ ] **Step 3: Add the minimal core models and engine**

```swift
public enum QuotaProvider: String, CaseIterable, Codable, Sendable {
    case codex
    case claude
}

public struct UsageWindow: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let remainingPercent: Int
    public let resetsAt: Date
}

public struct QuotaAccount: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let provider: QuotaProvider
    public let label: String
    public let priority: Int
    public let isCurrent: Bool
    public let windows: [UsageWindow]

    public var primaryRemainingPercent: Int { self.windows.first?.remainingPercent ?? 0 }
}

public extension QuotaAccount {
    static func codex(label: String, remainingPercent: Int, resetHours: Int, priority: Int, isCurrent: Bool) -> Self {
        QuotaAccount(
            id: UUID(),
            provider: .codex,
            label: label,
            priority: priority,
            isCurrent: isCurrent,
            windows: [
                UsageWindow(
                    id: "session",
                    title: "Session",
                    remainingPercent: remainingPercent,
                    resetsAt: Date().addingTimeInterval(Double(resetHours) * 3600)
                )
            ]
        )
    }

    static func claude(label: String, remainingPercent: Int, resetHours: Int, priority: Int, isCurrent: Bool) -> Self {
        QuotaAccount(
            id: UUID(),
            provider: .claude,
            label: label,
            priority: priority,
            isCurrent: isCurrent,
            windows: [
                UsageWindow(
                    id: "weekly",
                    title: "Weekly",
                    remainingPercent: remainingPercent,
                    resetsAt: Date().addingTimeInterval(Double(resetHours) * 3600)
                )
            ]
        )
    }
}

public struct GlobalRules: Codable, Equatable, Sendable {
    public let switchThresholdPercent: Int
    public let minimumScoreAdvantage: Int
    public let providerWeights: [QuotaProvider: Int]

    public static let `default` = GlobalRules(
        switchThresholdPercent: 20,
        minimumScoreAdvantage: 15,
        providerWeights: [.codex: 50, .claude: 50])
}

public enum RecommendationAction: String, Codable, Equatable, Sendable {
    case stayCurrent
    case recommendSwitch
}

public struct RecommendationDecision: Codable, Equatable, Sendable {
    public let recommendedAccountID: UUID
    public let action: RecommendationAction
}
```

```swift
public struct RecommendationEngine: Sendable {
    public init() {}

    public func evaluate(accounts: [QuotaAccount], rules: GlobalRules) -> RecommendationDecision {
        let ranked = accounts.sorted { self.score(for: $0, rules: rules) > self.score(for: $1, rules: rules) }
        let current = accounts.first(where: \.isCurrent) ?? ranked.first!
        let recommended = ranked.first!

        let currentScore = self.score(for: current, rules: rules)
        let recommendedScore = self.score(for: recommended, rules: rules)

        let shouldSwitch = current.primaryRemainingPercent <= rules.switchThresholdPercent
            && recommended.id != current.id
            && recommendedScore - currentScore >= rules.minimumScoreAdvantage

        return RecommendationDecision(
            recommendedAccountID: shouldSwitch ? recommended.id : current.id,
            action: shouldSwitch ? .recommendSwitch : .stayCurrent)
    }

    private func score(for account: QuotaAccount, rules: GlobalRules) -> Int {
        account.primaryRemainingPercent + account.priority + (rules.providerWeights[account.provider] ?? 0)
    }
}
```

- [ ] **Step 4: Seed deterministic demo accounts**

```swift
public enum DemoAccountRepository {
    public static func makeAccounts(now: Date = .now) -> [QuotaAccount] {
        let makeResetDate: (Int) -> Date = { now.addingTimeInterval(Double($0) * 3600) }
        return [
            QuotaAccount(
                id: UUID(),
                provider: .codex,
                label: "Codex Personal",
                priority: 75,
                isCurrent: true,
                windows: [UsageWindow(id: "session", title: "Session", remainingPercent: 58, resetsAt: makeResetDate(2))]
            ),
            QuotaAccount(
                id: UUID(),
                provider: .codex,
                label: "Codex Work",
                priority: 60,
                isCurrent: false,
                windows: [UsageWindow(id: "session", title: "Session", remainingPercent: 14, resetsAt: makeResetDate(5))]
            ),
            QuotaAccount(
                id: UUID(),
                provider: .claude,
                label: "Claude Max",
                priority: 85,
                isCurrent: false,
                windows: [UsageWindow(id: "weekly", title: "Weekly", remainingPercent: 73, resetsAt: makeResetDate(1))]
            ),
            QuotaAccount(
                id: UUID(),
                provider: .claude,
                label: "Claude Team",
                priority: 65,
                isCurrent: false,
                windows: [UsageWindow(id: "weekly", title: "Weekly", remainingPercent: 32, resetsAt: makeResetDate(6))]
            ),
        ]
    }
}
```

- [ ] **Step 5: Run the tests and confirm green**

Run: `xcodebuild test -project QuotaPilot.xcodeproj -scheme QuotaPilot -derivedDataPath build/DerivedData -only-testing:QuotaPilotTests/RecommendationEngineTests`
Expected: PASS with `2 tests, 0 failures`

- [ ] **Step 6: Commit the tested core**

```bash
git add Sources/QuotaPilotCore Tests/QuotaPilotTests
git commit -m "feat: add shared quota recommendation core"
```

### Task 3: Build The Menu Bar App And Dashboard Window

**Files:**
- Create: `Sources/QuotaPilotApp/App/QuotaPilotApp.swift`
- Create: `Sources/QuotaPilotApp/App/QuotaPilotAppDelegate.swift`
- Create: `Sources/QuotaPilotApp/Stores/AppModel.swift`
- Create: `Sources/QuotaPilotApp/Views/DashboardView.swift`
- Create: `Sources/QuotaPilotApp/Views/StatusMenuView.swift`
- Create: `Sources/QuotaPilotApp/Views/RecommendationCard.swift`
- Create: `Sources/QuotaPilotApp/Views/AccountRowView.swift`

- [ ] **Step 1: Add the app model that loads demo accounts**

```swift
import Observation
import QuotaPilotCore

@Observable
final class AppModel {
    var accounts: [QuotaAccount] = DemoAccountRepository.makeAccounts()
    var rules: GlobalRules = .default

    var decision: RecommendationDecision {
        RecommendationEngine().evaluate(accounts: self.accounts, rules: self.rules)
    }

    var recommendedAccount: QuotaAccount? {
        self.accounts.first(where: { $0.id == self.decision.recommendedAccountID })
    }
}
```

- [ ] **Step 2: Add the SwiftUI app entrypoint with a dashboard window and menu bar extra**

```swift
import SwiftUI

@main
struct QuotaPilotApp: App {
    @State private var model = AppModel()
    @NSApplicationDelegateAdaptor(QuotaPilotAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("QuotaPilot", id: "dashboard") {
            DashboardView(model: model)
                .frame(minWidth: 900, minHeight: 560)
        }

        MenuBarExtra("QuotaPilot", systemImage: "gauge.with.dots.needle.67percent") {
            StatusMenuView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            Text("Settings arrive in the next slice.")
                .padding(24)
        }
    }
}
```

```swift
import AppKit

final class QuotaPilotAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 3: Add the core dashboard views**

```swift
struct DashboardView: View {
    let model: AppModel

    var body: some View {
        NavigationSplitView {
            List(model.accounts) { account in
                AccountRowView(account: account, isRecommended: account.id == model.recommendedAccount?.id)
            }
            .listStyle(.sidebar)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RecommendationCard(account: model.recommendedAccount, action: model.decision.action)
                    ForEach(model.accounts) { account in
                        AccountRowView(account: account, isRecommended: account.id == model.recommendedAccount?.id)
                    }
                }
                .padding(24)
            }
        }
    }
}
```

```swift
struct StatusMenuView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RecommendationCard(account: model.recommendedAccount, action: model.decision.action)
            Divider()
            ForEach(model.accounts) { account in
                AccountRowView(account: account, isRecommended: account.id == model.recommendedAccount?.id)
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}
```

```swift
struct RecommendationCard: View {
    let account: QuotaAccount?
    let action: RecommendationAction

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(action == .recommendSwitch ? "Recommended Switch" : "Current Best Account")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(account?.label ?? "No recommendation")
                .font(.headline)
            Text("\(account?.primaryRemainingPercent ?? 0)% remaining")
                .font(.title3.bold())
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
```

```swift
struct AccountRowView: View {
    let account: QuotaAccount
    let isRecommended: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: account.provider == .codex ? "bolt.horizontal.circle" : "brain.head.profile")
                .foregroundStyle(isRecommended ? .tint : .secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.label)
                Text("\(account.primaryRemainingPercent)% remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isRecommended {
                Text("Best")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.tint.opacity(0.15), in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 4: Verify the app builds and launches**

Run: `./script/build_and_run.sh --verify`
Expected: build succeeds and `pgrep -x QuotaPilot` exits successfully

- [ ] **Step 5: Commit the app shell**

```bash
git add Sources/QuotaPilotApp
git commit -m "feat: add menu bar app shell"
```

### Task 4: Add The Widget Shell And Full Build Verification

**Files:**
- Create: `Sources/QuotaPilotWidget/QuotaPilotWidget.swift`
- Modify: `project.yml`

- [ ] **Step 1: Add the widget timeline provider using the shared seeded data**

```swift
import WidgetKit
import SwiftUI
import QuotaPilotCore

struct QuotaPilotEntry: TimelineEntry {
    let date: Date
    let recommended: QuotaAccount?
}

struct QuotaPilotProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuotaPilotEntry {
        QuotaPilotEntry(date: .now, recommended: DemoAccountRepository.makeAccounts().first)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuotaPilotEntry) -> Void) {
        let accounts = DemoAccountRepository.makeAccounts()
        let decision = RecommendationEngine().evaluate(accounts: accounts, rules: .default)
        completion(QuotaPilotEntry(date: .now, recommended: accounts.first { $0.id == decision.recommendedAccountID }))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuotaPilotEntry>) -> Void) {
        let accounts = DemoAccountRepository.makeAccounts()
        let decision = RecommendationEngine().evaluate(accounts: accounts, rules: .default)
        let entry = QuotaPilotEntry(date: .now, recommended: accounts.first { $0.id == decision.recommendedAccountID })
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
    }
}
```

- [ ] **Step 2: Add the widget body**

```swift
@main
struct QuotaPilotWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuotaPilotWidget", provider: QuotaPilotProvider()) { entry in
            VStack(alignment: .leading, spacing: 8) {
                Text("Best Next Account")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.recommended?.label ?? "Unavailable")
                    .font(.headline)
                Text("\(entry.recommended?.primaryRemainingPercent ?? 0)% remaining")
                    .font(.title3.bold())
            }
            .padding()
        }
        .configurationDisplayName("QuotaPilot")
        .description("Shows the current recommended account.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

- [ ] **Step 3: Run the full test and build verification**

Run: `xcodebuild test -project QuotaPilot.xcodeproj -scheme QuotaPilot -derivedDataPath build/DerivedData && ./script/build_and_run.sh --verify`
Expected: tests pass, the app launches, and the widget target compiles with the project

- [ ] **Step 4: Commit the widget shell**

```bash
git add Sources/QuotaPilotWidget project.yml
git commit -m "feat: add desktop widget shell"
```
