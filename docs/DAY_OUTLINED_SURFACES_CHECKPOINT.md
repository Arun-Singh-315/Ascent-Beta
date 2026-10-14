# Day outlined surfaces checkpoint — 14 October 2026

Branch: feature/day-outlined-surfaces. User's existing agent-workflow edits were preserved.

## Phone builds
- Timer-only 1.0.12 (13) was installed and launched successfully before starting the visual migration.
- Final APK: releases/Ascent-1.0.13-14-day-outlined-arm64.apk
- SHA-256: 2d3057f3e420d671669dae6deb921dc42482c6f15799f0f2f99e1023fce7dc3f
- Final installation: SUCCESS
- Installed metadata: versionCode=14 minSdk=24 targetSdk=36
versionName=1.0.13

## Audit and implementation
Existing central sources were app_theme.dart, color_tokens.dart, AscentGlass, dimension_tokens.dart, and text_styles.dart; shared surfaces were AscentCard and GlassSurface. Screen-local decorations, chips, typography and separators were widespread.

New semantic surfaces are in lib/app/theme/surface_tokens.dart. Shared roles are AppCard, AppPill, AppTag and AppDivider in lib/shared/widgets/app_surfaces.dart. Existing cards and glass surfaces delegate to the shared roles. Day cards are transparent with 1.5px ink borders; interactive pills are transparent with 1px ink borders, selected states fill the accent with white text, informational tags use tinted accent surfaces, and avatars have no border. Day blur/shadow/gradient surface effects are removed. Progress, indicators and accessible targets have separate shared semantic helpers. Typography is consolidated in the existing central text_styles.dart. Riya's source was not changed, and its route is scoped to the original presentation.

Home has a single day header row, a wrapping full name, greeting, profession tag and Customize pill. Names remain complete at large text sizes (may occupy more than two lines to avoid truncation). Day hit targets are at least 44px; the day heatmap scrolls to accommodate its hit targets. Fullscreen day lecture-player background and wrapping metadata were corrected during screenshot QA.

Timer completion now rejects attempts before the full activity target, counts earlier completed focus sessions, excludes pause time, and preserves the running/paused session on rejection. DAO and UI completion guards are covered by tests.

## Validation
- Full suite: 442 tests passed before final selected-state/player polish.
- Final broad regression: 67 tests passed after selected-state polish, including the 48 screen/theme renders, Home/notes accessibility and selection/action behavior.
- Final player day/night regression: 2 passed after final player correction.
- Final flutter analyze: no issues.
- 24 night screenshots matched the original checkout pixel for pixel before the final player-only background/metadata correction; that correction preserves all night values and passed the night render test.
- Screenshot artifacts: build/qa/day-surfaces; narrow/large-text artifacts: build/qa/mindspace.
- APK build succeeded and installation result is recorded above.

## Retained exceptions / remaining cleanup
Riya is intentionally excluded. Reader-page palettes and data-dependent chart/indicator colors retain their meanings. Original night Analytics/Hydration metadata overflows at 390px are preserved as requested; their night audit uses 480px.

The strict no-brightness-checks-in-screens cleanup is not fully complete: 17 legacy brightness references remain, largely for preserved night decoration colors and existing theme controls (Home header/preview/activity row; thought-wall sheets/bubble; hydration popup; activity/course sheets; Chai/breathing; Walk; in-app reminder controls). New day surface roles do not branch on brightness in screens. These references should be moved to central semantic tokens in a follow-up while retaining night pixel equivalence.

No navigation/content changes were intended beyond the explicitly requested timer completion fix. No new unrelated feature was started. Existing user app data was retained by installing with adb install -r.
