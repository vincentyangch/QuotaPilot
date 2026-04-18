# QuotaPilot Polish Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the current QuotaPilot backlog by adding a true global recommendation model, improving recovery visibility and restore history, and polishing launch/startup behavior for a menu bar-first app.

**Architecture:** Keep the existing app shape, but promote recommendation logic from provider-scoped decisions to a shared cross-provider decision that still preserves provider-level detail for inventory and activation flows. Extend the existing activity log and settings surfaces instead of introducing new persistence systems, and add startup preferences through small focused services that the app model owns.

**Tech Stack:** Swift 6, SwiftUI, Observation, WidgetKit, ServiceManagement, XCTest, XcodeGen

---

### Task 1: Promote Recommendations To A Global Cross-Provider Decision

**Files:**
- Modify: `Sources/QuotaPilotCore/Services/RecommendationEngine.swift`
- Modify: `Sources/QuotaPilotCore/Models/RecommendationDecision.swift`
- Modify: `Sources/QuotaPilotCore/Services/QuotaPilotWidgetProjection.swift`
- Modify: `Sources/QuotaPilotCore/Models/QuotaPilotWidgetSnapshot.swift`
- Modify: `Sources/QuotaPilotApp/Stores/AppModel.swift`
- Modify: `Sources/QuotaPilotApp/Views/DashboardView.swift`
- Modify: `Sources/QuotaPilotApp/Views/StatusMenuView.swift`
- Modify: `Sources/QuotaPilotApp/Views/RecommendationCard.swift`
- Test: `Tests/QuotaPilotTests/RecommendationEngineTests.swift`
- Test: `Tests/QuotaPilotTests/QuotaPilotWidgetProjectionTests.swift`

- [ ] **Step 1: Add failing tests for a single best account across providers**
- [ ] **Step 2: Run `xcodebuild test -project QuotaPilot.xcodeproj -scheme QuotaPilot -derivedDataPath build/DerivedData -only-testing:QuotaPilotTests/RecommendationEngineTests -only-testing:QuotaPilotTests/QuotaPilotWidgetProjectionTests` and confirm the new expectations fail for the old provider-scoped behavior**
- [ ] **Step 3: Refactor the recommendation engine so it can produce one global decision plus provider-grouped rankings without breaking activation lookup helpers**
- [ ] **Step 4: Reproject app and widget state from the global decision so the UI can show current account, best next account, warning state, and explanation consistently**
- [ ] **Step 5: Re-run the targeted tests and make them pass before touching adjacent UI polish**

### Task 2: Expand Recovery Center Controls, Restore History, And Restore Provenance

**Files:**
- Modify: `Sources/QuotaPilotCore/Models/ActivityLogEntry.swift`
- Modify: `Sources/QuotaPilotCore/Services/ActivityLogStore.swift`
- Modify: `Sources/QuotaPilotApp/Stores/AppModel.swift`
- Modify: `Sources/QuotaPilotApp/Views/RulesSettingsView.swift`
- Modify: `Sources/QuotaPilotApp/Views/ActivityLogSectionView.swift`
- Test: `Tests/QuotaPilotTests/ActivityLogStoreTests.swift`
- Test: `Tests/QuotaPilotTests/LocalProfileActivatorTests.swift`

- [ ] **Step 1: Add failing tests for structured restore metadata and for preserving it through activity-log persistence**
- [ ] **Step 2: Run `xcodebuild test -project QuotaPilot.xcodeproj -scheme QuotaPilot -derivedDataPath build/DerivedData -only-testing:QuotaPilotTests/ActivityLogStoreTests -only-testing:QuotaPilotTests/LocalProfileActivatorTests` and confirm the new restore-history expectations fail first**
- [ ] **Step 3: Extend restore logging so each restore records what backup was applied and what active/ambient profile it replaced when known**
- [ ] **Step 4: Add recovery-center controls for `Expand All` / `Collapse All` and replace the “latest only” recovery view with a short history list that shows the new provenance**
- [ ] **Step 5: Re-run the targeted tests and keep the settings/recovery flow green before moving on**

### Task 3: Add Launch-At-Login And Startup Behavior Settings

**Files:**
- Create: `Sources/QuotaPilotCore/Models/StartupBehavior.swift`
- Create: `Sources/QuotaPilotCore/Services/StartupBehaviorStorage.swift`
- Create: `Sources/QuotaPilotApp/Support/LaunchAtLoginController.swift`
- Modify: `Sources/QuotaPilotApp/Stores/AppModel.swift`
- Modify: `Sources/QuotaPilotApp/App/QuotaPilotApp.swift`
- Modify: `Sources/QuotaPilotApp/App/QuotaPilotAppDelegate.swift`
- Modify: `Sources/QuotaPilotApp/Views/RulesSettingsView.swift`
- Test: `Tests/QuotaPilotTests/StartupBehaviorStorageTests.swift`

- [ ] **Step 1: Add failing tests for persisted startup behavior defaults and updates**
- [ ] **Step 2: Run `xcodebuild test -project QuotaPilot.xcodeproj -scheme QuotaPilot -derivedDataPath build/DerivedData -only-testing:QuotaPilotTests/StartupBehaviorStorageTests` and verify the new settings are missing before implementation**
- [ ] **Step 3: Add a small launch-at-login controller and startup-behavior storage that lets the app launch into the menu bar without always opening the dashboard**
- [ ] **Step 4: Wire the new settings into the app entrypoint and Settings UI so users can control launch-at-login and dashboard-on-launch behavior**
- [ ] **Step 5: Re-run the targeted tests, then run the full app test suite and build verification**

### Task 4: Full Verification And Review

**Files:**
- Verify only

- [ ] **Step 1: Run `xcodebuild test -project QuotaPilot.xcodeproj -scheme QuotaPilot -derivedDataPath build/DerivedData`**
- [ ] **Step 2: Run `./script/build_and_run.sh --verify`**
- [ ] **Step 3: Review the diff for each feature area and confirm there are no unrequested scope leaks before reporting completion**
