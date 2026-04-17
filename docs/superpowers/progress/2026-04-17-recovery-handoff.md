# QuotaPilot Recovery Handoff

- Date: `2026-04-17`
- Branch: `main`
- Remote: `origin/main`
- Latest implementation commit before this handoff note: `c0eeab2 feat: persist recovery center expansion`

## Current Product State

QuotaPilot is now a working native macOS app with:

1. Dashboard window, menu bar extra, and desktop widget.
2. Ambient/local profile discovery for `Codex` and `Claude`.
3. Live usage loading, provider-scoped recommendation logic, and current-profile selection.
4. Local profile activation plus managed ambient-backup creation.
5. Recommendation alerts, background refresh, and widget snapshot persistence.
6. Provider health, tracked-profile lifecycle states, and automatic activation recovery warnings.
7. Managed-backup delete, restore, confirmation, and restore-history surfacing.
8. Settings-based recovery center with grouped sections, counts, and persisted disclosure state.

## Recovery Work Landed

The recovery-focused slices added in this run are:

1. Managed-backup delete from tracked profiles, with path-safety checks.
2. Removal of demo fallback from the app and widget in favor of honest empty states.
3. Confirmations for destructive profile-source removal and backup deletion.
4. Stale-account and stale-profile warnings when refresh falls back to older live snapshots.
5. Provider health recovery checklists and inline quick actions.
6. Tracked-profile recovery actions, including managed-backup restore suggestions.
7. Provider-level managed-backup restore suggestions.
8. Confirmation dialogs before managed-backup restores.
9. Latest backup restore surfaced in activity/status UI.
10. Recovery center in Settings, then grouped into:
   - `Needs Attention`
   - `Restore Options`
   - `Recent Recovery`
11. Recovery-center count badges and persisted expansion state.

## Most Recent Commits

1. `c0eeab2 feat: persist recovery center expansion`
2. `0c83b79 feat: collapse recovery center groups`
3. `8e4980e feat: add recovery center counts`
4. `a0cf04b feat: group recovery center sections`
5. `a2555f0 feat: add recovery center to settings`
6. `18870fb feat: surface latest backup restore`
7. `8d79b77 feat: confirm managed backup restores`
8. `5dcd7ad feat: add provider backup restore action`
9. `610dcf0 feat: describe backup restores clearly`
10. `f371ad8 feat: suggest managed backup restore`
11. `78aeaca feat: flag stale tracked profiles`
12. `78bcb70 feat: add tracked profile recovery actions`

## Best Resume Points

The strongest next slices from here are:

1. Add `Expand All` / `Collapse All` controls to the Settings recovery center.
2. Surface backup-restore history beyond the latest event, for example a short restore timeline or filtered history view.
3. Add launch-at-login and startup-behavior polish now that the recovery/status loop is mature.
4. Add more precise restore provenance, such as which ambient/current profile was replaced by a given restore.

## Verification Baseline

The latest completed verification at this checkpoint:

1. `xcodebuild test -project QuotaPilot.xcodeproj -scheme QuotaPilot -derivedDataPath build/DerivedData`
2. `./script/build_and_run.sh --verify`

Both were passing before this handoff note was written.
