---
name: firebase-app-distribution
description: Archive the SPAJAM2026App iOS app and upload it to Firebase App Distribution so testers can install it. Use this whenever the user asks to distribute, upload, ship, or deliver a build to testers or to Firebase / App Distribution, to "配布" or "アップロード" the app, or to give a tester group (e.g. SPAJAM2026) the latest build — even if they don't mention Firebase by name.
---

# Firebase App Distribution

Build a Release archive of `SPAJAM2026App`, export it, and upload it to
Firebase App Distribution with `scripts/distribute.sh`. The script already
encodes the project ID, app ID, scheme, and export options, so the work here
is mostly about choosing the right inputs and verifying the result.

## Workflow

### 1. Check the branch state

Run `git fetch` and `git status -sb`. The build ships whatever is checked out,
so uncommitted changes or a stale branch end up in testers' hands silently.
If the working tree is dirty, say so before building — the user may want
those changes included, or may not. Don't switch branches on your own.

Don't commit or push anything as part of distribution; the script only reads
the repository.

Also confirm `SPAJAM2026App/Secrets.plist` exists. It is gitignored and the
app does **not** fail without it — `TripSession` silently falls back to
`MockPhotoAIJudge` when no key is found — so a build made without it would
ship a mock AI judge to testers with no error anywhere. If it's missing, tell
the user to copy `Secrets.sample.plist` and fill in keys from the team
spreadsheet; don't invent or paste keys yourself.

### 2. Resolve the tester group

The team's only tester group is **SPAJAM2026**, whose alias is `spajam2026`.
When the user doesn't name a group, use `spajam2026` — that is what "配布して"
means in this project, and uploading without a group creates a release that
nobody is notified about.

If the user names a different group, remember that
`firebase appdistribution:distribute --groups` takes the group **alias**, not
the display name shown in the console, so look it up:

```bash
firebase appdistribution:group:list --project spajam2026-app
```

Match the requested name against the `Display Name` column
(case-insensitively) and use the value in the `Group` column. If nothing
matches, show the user the table and stop rather than guessing.

If this command fails with an auth error, the Firebase CLI isn't logged in.
Ask the user to run `firebase login` in their terminal; it opens a browser
sign-in that you can't complete for them.

### 3. Build and upload

```bash
FIREBASE_TESTER_GROUPS=spajam2026 scripts/distribute.sh [release notes]
```

- Release notes default to `<last commit subject> (<short hash>)`. Pass a
  custom string as the first argument when the user supplies notes.
- The build takes several minutes (archive + export + upload). Give the Bash
  call a long timeout (≥ 600 000 ms) and pipe through `tail` — the full
  xcodebuild log is noisy and mostly Swift 6 concurrency warnings from
  `SPAJAM2026AppShared`, which are expected and do not block the export.
- The script runs `rm -rf build/distribution` before archiving, so a failed
  run leaves no half-built artefacts to clean up; just rerun it.

### 4. Report

Tell the user, briefly:

- release version/build number (from `uploaded new release X (Y)`)
- which commit was built, and the branch
- the group it was distributed to
- the Firebase console link printed by the CLI

Skip the one-hour binary download link — it expires quickly and the console
link is what people come back to.

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `No profiles for 'app.kymmt.SPAJAM2026App'` or signing error during archive | The local `DEVELOPMENT_TEAM` in project.pbxproj doesn't match the user's Apple team. Per CLAUDE.md they rewrite it locally and must not commit it; ask them to set it in Xcode rather than editing it yourself. |
| Testers report the AI judge always returns canned results | `Secrets.plist` was missing when the archive was built (see step 1). Add it and redistribute. |
| `Command line name "development" is deprecated` | Harmless warning from `ExportOptions.plist`; ignore. |
| Upload succeeds but says `distributed to testers/groups` is missing | `FIREBASE_TESTER_GROUPS` was not set — the release exists but nobody was notified. Re-distribute from the console or rerun with the group. |
| `firebase` not found | It is installed via mise (`~/.local/share/mise/shims/firebase`); make sure the shell has mise shims on `PATH`. |
