# QuotaPilot Design

- Date: 2026-04-16
- Product: QuotaPilot
- Status: Drafted from approved design discussion; pending written-spec review

## Summary

QuotaPilot is a macOS menu bar app with a companion desktop widget that monitors AI usage across multiple accounts and helps users move to the best available account when usage is constrained.

Version 1 focuses on `Codex` and `Claude`, uses a safe read-only default that reuses existing local credentials and sessions, and adds a global rules engine that can notify, recommend, confirm, or automatically switch where automation is reliable. In v1, CLI environments can support automatic switching while desktop app workflows use guided handoff.

The core product promise is:

`QuotaPilot watches Codex and Claude usage across multiple accounts, recommends the best account under a global rules engine, and can safely automate CLI switching while guiding desktop handoff.`

## Goals

1. Make current and remaining usage visible across multiple `Codex` and `Claude` accounts.
2. Provide a single recommendation for the best next account using a configurable global scoring model.
3. Support multiple automation modes:
   - notify only
   - recommend
   - confirm before switch
   - automatic switching where the connector supports it safely
4. Keep the default posture safe by reusing existing machine state instead of owning credentials by default.
5. Expose the same core state in both the menu bar app and a desktop widget.

## Non-Goals For V1

1. Full browser session orchestration.
2. Fully automatic desktop session mutation for every provider.
3. Per-project or per-workspace routing rules.
4. Cross-device sync.
5. Support for providers beyond `Codex` and `Claude`.
6. Advanced historical analytics beyond the core usage dashboard and recommendation state.

## Product Surfaces

### Menu Bar App

The menu bar app is the primary control surface. It should show:

- current account status
- current recommendation
- usage state for known accounts
- switch actions
- connector health
- settings and policy controls

This is where the user configures providers, thresholds, action modes, and the global rules engine.

### Desktop Widget

The widget is a compact always-visible dashboard. It should show:

- current active provider/account
- top recommendation
- remaining usage summary across important windows
- warning state when the current account is near or below threshold

The widget is informational first. It should reflect the same underlying state as the menu bar app instead of implementing separate logic.

### Background Coordinator

QuotaPilot needs a background coordinator that refreshes usage, evaluates rules, and triggers notifications or switching flows even when the main menu is closed.

## Architecture

QuotaPilot v1 should be built around five layers.

### 1. Provider Connectors

Provider connectors are responsible for reading usage and account identity from `Codex` and `Claude`.

Design rules:

- Prefer local first-party state and supported APIs over scraping.
- Reuse existing machine credentials by default.
- Keep provider-specific parsing isolated.
- Report capability flags along with usage so the rest of the app knows what each connector can safely do.

Initial connector strategy should follow the broad `CodexBar` pattern:

- `Codex`: local auth/session state first, then supported CLI or local fallback paths when needed.
- `Claude`: local OAuth/session state first, then supported CLI or controlled web fallback paths when needed.

### 2. Account Registry

The account registry is the normalized internal model for all known accounts. Each account should include:

- provider
- user-facing label
- identity hints such as email, org, workspace, and plan
- live usage windows
- last refresh time
- connector health
- switching capabilities
- ownership mode

Ownership mode should distinguish:

- externally owned account
- QuotaPilot-managed account

Capability flags should distinguish:

- can read usage
- can recommend
- can guide desktop switching
- can auto-switch CLI

### 3. Rules Engine

The rules engine is the core product differentiator for v1.

It should:

- use one global rule set for all accounts
- support threshold-based switching triggers
- support score-based comparison between accounts
- require a meaningful advantage before recommending or switching
- explain why a recommendation was made

The rules engine should optimize with a combined scoring model rather than a single metric. The initial model should combine:

- remaining quota
- reset time
- provider preference
- account priority

Default trigger behavior should combine two ideas chosen during design:

- act when the current account drops below a configured floor
- act when another account scores materially better under the rules engine

### 4. Switch Orchestrator

The switch orchestrator converts a recommendation into an action.

Supported v1 action paths:

- `CLI`: automatic switching when the provider connector exposes a safe switching path
- `Desktop apps`: guided handoff only

Action modes exposed to the user:

- notify only
- recommend only
- require confirmation
- auto-switch where supported

The orchestrator must never assume a switch succeeded. It should verify the resulting active identity after any action and move to a recovery state if verification fails.

### 5. UI Projection Layer

The UI projection layer converts internal state into display-friendly view models for:

- menu bar content
- widget content
- notifications
- settings summaries

This layer keeps product logic out of the UI and ensures the widget and menu bar stay consistent.

## Account Model

Each normalized account record should include the following fields or their equivalents:

- stable account ID
- provider ID
- display label
- email
- organization or workspace label
- plan
- ownership mode
- capability flags
- primary usage window
- secondary usage window
- optional tertiary or provider-specific window
- current recommendation score
- current recommendation rank
- current health state
- last successful refresh time
- last error state

The account model should make provider differences explicit without leaking provider-specific parsing details into the rest of the app.

## Switching Lifecycle

QuotaPilot should model switching as a six-step lifecycle.

### 1. Discover

Discover accounts from local machine state and from optional user-added accounts.

### 2. Refresh

Refresh provider usage and identity data on a schedule and on user-triggered actions.

### 3. Evaluate

Run the global rules engine to determine:

- current account health
- whether the current account is below threshold
- whether another account is materially better
- which action mode applies

### 4. Decide

Choose the correct action:

- notify
- recommend
- confirm
- auto-switch

### 5. Execute

Perform the selected action through the appropriate surface:

- automatic CLI switch where supported
- guided desktop handoff otherwise

### 6. Verify

Re-check active account identity and usage context after the action. If the result does not match the intended target, stop automation and surface a clear recovery state instead of retrying blindly.

## Default Security And Credential Posture

QuotaPilot v1 should default to the safest practical mode:

- read-only by default
- reuse credentials and sessions that already exist on the machine
- do not silently capture or invent new credential storage paths
- keep any app-owned secret material in macOS Keychain where applicable
- keep app-owned account metadata under Application Support with restrictive file permissions

Managed profiles and deeper automation should exist as an explicit advanced mode later, not as the default onboarding path.

## V1 Scope

In scope:

1. macOS menu bar app.
2. macOS desktop widget.
3. `Codex` support.
4. `Claude` support.
5. Read-only account discovery by default.
6. Usage polling and normalization.
7. Global rules engine.
8. Action modes for notify, recommend, confirm, and supported auto-switch.
9. CLI auto-switch support.
10. Desktop guided handoff support.
11. Clear recommendation reasoning in the UI.

Out of scope:

1. Browser switching.
2. Per-project policies.
3. Full automatic desktop mutation for all providers.
4. Cross-device sync.
5. Expanded provider catalog.

## Reliability And Failure Handling

QuotaPilot should treat provider connectivity and automation as unreliable by default and recover gracefully.

Required failure states:

- usage unavailable
- identity unresolved
- auth expired
- connector degraded
- switch failed verification
- desktop handoff required

For each of these states, the UI should communicate:

- what happened
- what QuotaPilot will do next automatically, if anything
- what the user can do manually

## Testing Strategy

V1 should include four kinds of testing.

### Provider Parsing Tests

Focused tests for `Codex` and `Claude` usage parsing, identity extraction, fallback handling, and normalization.

### Rules Engine Tests

Tests for:

- threshold logic
- score comparisons
- recommendation ranking
- meaningful-advantage gating
- action mode decisions

### Switching Flow Tests

Integration-style tests for CLI switching flows and verification logic.

### UI Projection Tests

Tests for menu bar and widget state projections to ensure the same internal state yields consistent user-facing results.

## Milestone Shape

The likely implementation order should be:

1. App shell with menu bar + widget plumbing.
2. Normalized account registry and persisted app state.
3. `Codex` and `Claude` usage connectors.
4. Rules engine and recommendation model.
5. Notifications and recommendation UX.
6. CLI switching flows.
7. Desktop guided handoff flows.
8. Hardening, verification, and failure-state polish.

## Design Decisions Captured

The following decisions were made during brainstorming and are locked into this v1 design:

1. Product form factor: menu bar app plus desktop widget.
2. Initial providers: `Codex` and `Claude`.
3. Usage dashboard is a first-class feature.
4. `CodexBar` is a structural reference, not a strict clone.
5. QuotaPilot should outperform that reference primarily through smarter automation.
6. Default credential posture is safe read-only reuse of existing machine state.
7. Switching model is hybrid:
   - managed where explicitly enabled later
   - guided fallback where direct automation is unsafe
8. Rules are global only in v1.
9. Default trigger behavior combines threshold-based and score-based switching.
10. V1 switching targets are CLI and desktop app surfaces, not browsers.
11. CLI may auto-switch in v1; desktop apps use guided handoff in v1.

## Open Constraints To Confirm During Planning

These are not product-definition gaps, but implementation constraints that need confirmation during planning:

1. Exact CLI switching mechanics available for the supported `Codex` and `Claude` environments.
2. Exact desktop handoff capabilities for the chosen macOS app targets.
3. Minimum macOS version and widget feature baseline.
4. Whether the initial build should be pure SwiftUI or use selective AppKit interop for menu bar behavior.

These items should be resolved in the implementation plan, not by changing the product goals above.
