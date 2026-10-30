# Repository working rules

## Existing app and user data

Android updates must replace the user's existing installed app while preserving its data. Inspect the connected device's package and signing certificate, build the matching variant, back up app data privately, and install with `adb install -r`. Never uninstall, clear app data, change the application ID, or install a second variant on the user's phone to work around an update problem. Verify that the original data is unchanged before launching the update. If signing or package identity prevents an update, report the blocker without resetting the app.

## Consistent UI and UX

Before implementing a feature or interaction, inspect the existing equivalent implementation and reuse its components, theme, spacing, gestures, and animation conventions. In particular, compare swipe actions with the existing archive swipe: use themed action containers, avoid white reveal gaps, and check both swipe directions. Avoid duplicate text in cards. Check the changed flow on a mobile viewport and, when connected, on the existing phone app without modifying the user's personal records for testing.

## Temporary planning files

Implementation plans and task-specific planning documents are temporary working files. After the implementation and verification are complete, delete those files before finishing the task. Do not commit or retain them unless the user explicitly asks to keep them. Preserve maintained product documentation, user-owned files, and repository instructions such as this file.

## Shared interaction controls

Use `AscentSwitch` for standalone switches and `AscentSwitchRow` for settings. Use `AscentSegmentedControl` for mutually exclusive options, including its large-text vertical layout. Do not introduce raw Switch, Switch.adaptive, CupertinoSwitch, or per-screen segmented controls. SharedControlColors owns interaction colors: blue for actions and selection, red for overdue/destructive states, neutral grey for structure. Importance uses a user-selected star, not a yellow priority badge.
