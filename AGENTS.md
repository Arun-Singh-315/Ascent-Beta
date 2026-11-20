# Repository working rules

**[CLAUDE.md](CLAUDE.md) is the single source of truth** for product identity (premium personal OS), the "never later" ease principle, the Apple-premium visual language, navigation, hero surfaces (Home, Things Hub, Thought Wall), component contracts and offline/online rules. Read it before any change. If anything here or in `docs/` conflicts with it, CLAUDE.md wins. Fix the conflicting file in the same change.

## Existing app and user data

Android updates must replace the user's existing installed app while preserving its data. Inspect the connected device's package and signing certificate, build the matching variant, back up app data privately, and install with `adb install -r`. Never uninstall, clear app data, change the application ID, or install a second variant on the user's phone to work around an update problem. Verify that the original data is unchanged before launching the update. If signing or package identity prevents an update, report the blocker without resetting the app.

## Consistent UI and UX

Before implementing a feature or interaction, inspect the existing equivalent implementation and reuse its components, theme, spacing, gestures, and animation conventions (CLAUDE.md §6). Swipe actions use themed action containers with no white reveal gaps; check both swipe directions. Avoid duplicate text in cards. Check the changed flow on a mobile viewport (320 px, text scale 2.0, light and dark) and, when connected, on the existing phone app without modifying the user's personal records.

## Shared interaction controls

Use `AscentSwitch` / `AscentSwitchRow`, `AscentSegmentedControl` (including its large-text vertical layout), `AscentButton`, `EmptyState`, `AppTextField` / `AppComposer`, `AscentSheet`, `AscentDialog`, `AscentPopupMenu` and `showUndoSnackbar`. Never introduce raw Material or Cupertino equivalents or per-screen versions. Interaction colors come from the theme roles in CLAUDE.md §3.1: `action` blue for actions and selection, `danger` red for overdue/destructive states, `success` green for completion and switch tracks, neutral greys for structure. Importance uses a user-selected star, not a priority badge.

## Temporary planning files

Implementation plans and task-specific planning documents are temporary working files. After the implementation and verification are complete, delete them before finishing the task. Do not commit or retain them unless the user explicitly asks to keep them. Preserve maintained product documentation, user-owned files, and repository instructions such as this file.
