# Frozen Sky: theme audit and corrections

16 October 2026. The former Nordic Sky preset now appears as **Frozen Sky**. Its persisted `nordicSky` key is unchanged; no settings or record migration is needed.

## Why the earlier preset felt incomplete

| Confirmed source issue | Correction |
|---|---|
| Many `BuildContext` color helpers branched only on brightness, returning Classic Clay backgrounds, secondary accents and text even with Nordic selected. | Frozen surface, elevation, secondary text, action and semantic colors now resolve consistently through the selected preset. Classic Clay and night branches retain their existing palette. |
| Glass tokens mixed bright blue accents with warm copper; Material text buttons explicitly used blue. | Charcoal/slate supplies text, teal supplies filled controls, and aqua/mint/lavender supplies surfaces and atmosphere. Muted green, amber and red remain meaningful status colors. |
| Home identified presets by matching literal colors, then overrode the selected glass with transparent fills and warm glows. | A preserved preset marker identifies Frozen Sky; Home uses the frozen glass tokens instead of the warm override. |
| Riya painted its own warm atmosphere independently of the app theme. | Frozen Riya has a cool mist backdrop with neutral actions/text and the same surface tokens. |
| Reminder dialogs and primary shared buttons used hardcoded cream/brown presentation colors. | Those surfaces, controls and borders now follow Frozen tokens when selected. More and Thought Wall accents follow the same neutral presentation. Stored thought colors remain unchanged. |
| Glass blur ignored its surface token and always used 22px. | Frosted surfaces use their configured blur; Frozen uses a restrained 12px outside the unblurred Home presentation. |

The revised palette uses a cool mint canvas, lightly tinted cards, charcoal primary text, readable slate secondary text and teal filled actions. Home’s Riya gateway has a lavender fill and soft lavender border; the streak badge has a mint fill and selected navigation has an aqua fill with a teal icon. Inputs, modal surfaces, selected switches, shared cards, navigation and primary controls receive the preset. Screen purpose, data, timers and scheduling behavior are preserved; illustrative content and status meanings are not replaced with one decorative color.

## Unfinished plan wording and placement

The unexplained “Finish scheduling” line is replaced by an **Unscheduled plan** section attached directly to the matching thought. It says “No reminder set yet.” Drafts whose source is outside the preview have a separate card showing the draft title and “Saved as a thought. No reminder set yet.”

- **Review & schedule** reopens the saved review.
- **Keep as thought** removes only the schedule draft and preserves the original note.

Both actions remain available at narrow widths and enlarged text. A plan still requires approval before task/reminder creation.

## Verification

Focused batch: 23 tests passed. Full suite: **495 tests passed, no failures**. A subsequent on-device placement refinement passed 15 targeted Home/capture/layout tests. Static analysis: no issues found.

The first release attempt exposed a stale generated Android registrant containing the test-only integration plugin. After tests, build with `flutter build apk --release --target-platform android-arm64` so Flutter regenerates release tooling; skipping pub/tooling regeneration can retain the test registration. No dependency versions or Android source configuration needed changing.

The initial neutral ARM64 release APK (50.9MB) built successfully and was installed as an update on the A142, preserving the existing profile and notes. Native Home and task-sheet inspection confirmed neutral text, cool surfaces and slate action controls. The final Home screenshot confirmed that the matching thought contains “Unscheduled plan,” “No reminder set yet,” “Review & schedule” and “Keep as thought,” with its actions visible in the first viewport. Home was left open for review.

## Colour revision after device feedback

The first neutral version appeared too grey on the phone. The revision restores visible aqua and lavender atmosphere (the shared painter previously capped their opacity), replaces Home’s hard black feature outlines with soft tinted borders, and adds coloured selected surfaces. Text helpers and text buttons remain charcoal/slate; colour is concentrated in backgrounds, icons and filled controls. Classic and night theme branches retain their prior appearance.

Revision verification: 27 targeted theme, Home layout/header and scheduling tests passed; static analysis reported no issues. After slightly darkening muted text, all five shared theme/contrast checks passed again, including muted text on aqua, mint and lavender (at least 4.5:1) and white text on the teal action fill.

The colour revision release built successfully and was installed with `adb install -r` on the A142. A fresh device screenshot confirmed visible aqua/lavender atmosphere, the lavender Riya gateway, mint badge, tinted cards and teal selected Home navigation. The app was launched for review.
