# QuotaPilot Implementation Handoff

- Date: 2026-04-16
- Branch: `main`
- Remote: `origin/main`
- Latest commit at handoff: `1bf73b7 feat: add confirm switch mode`

## Current Product State

QuotaPilot is now a working native macOS app shell with a menu bar app, dashboard window, and desktop widget.

Implemented so far:

1. Native macOS project scaffold with XcodeGen, app target, widget target, tests, and local build/run tooling.
2. Shared provider/account/rules models plus recommendation engine with provider-scoped best-account decisions.
3. Real Codex and Claude branding assets taken from the CodexBar reference.
4. Ambient local profile discovery for:
   - `Codex` via `~/.codex/auth.json`
   - `Claude` via `~/.claude/.credentials.json`
   - `Claude` Keychain fallback via `Claude Code-credentials`
5. Live usage refresh from discovered local profiles.
6. Stored additional profile roots and per-provider current-profile selection.
7. Tracked-profile dashboard section and folder picker for adding profile roots.
8. Real local profile activation flow with ambient backup handling.
9. One-click activation of recommended local profiles when supported.
10. Widget fed from a persisted live app snapshot instead of demo-only data.
11. Recommendation alerts with dedupe, foreground presentation, and settings toggle.
12. Background refresh loop while the app is running.
13. Switch behavior modes:
   - `Recommend Only`
   - `Confirm Before Activating`
   - `Auto-Activate Local Profiles`

## Current UX Notes

`Confirm Before Activating` is implemented in the model and settings flow. Pending confirmations currently surface in Settings with `Approve` and `Dismiss` actions.

`Auto-Activate Local Profiles` only acts on supported local profiles that are both recommended and activatable. It does not blindly switch.

Alerts and widget updates are both driven off the same refreshed internal state.

## Strong Resume Points

Best next product slices:

1. Surface pending confirmations in the dashboard and/or menu bar, not just Settings.
2. Add a lightweight activity/history log for refreshes, alerts, confirmations, and switches.
3. Improve widget density:
   - current vs recommended
   - last refresh age
   - warning state when current account is below threshold
4. Add clearer verification/recovery state after automatic activation attempts.

## Recent Commits

1. `1bf73b7 feat: add confirm switch mode`
2. `beff8f6 feat: add switch action mode`
3. `3ed2939 feat: add background refresh loop`
4. `2f9c591 feat: add recommendation alerts`
5. `8e56eb6 feat: feed widget from live app snapshot`
6. `2f6000d feat: activate recommended profiles`

## Verification Baseline

The latest completed verification before this handoff:

1. `xcodebuild test -project QuotaPilot.xcodeproj -scheme QuotaPilot -derivedDataPath build/DerivedData`
2. `./script/build_and_run.sh --verify`

Both were passing at the latest implementation checkpoint.
