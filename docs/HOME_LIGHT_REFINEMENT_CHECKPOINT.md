# Home light refinement — 14 October 2026

Branch: feature/home-light-refinement.

## Restoration

The last committed baseline before the uncommitted outlined-day migration is `02e3e8e`. The earlier glass styling originated in `343e00d`; returning to that older commit would discard subsequent functional work.

Restoration disables the global outlined-day override and lets migrated widgets use their retained pre-migration decorations. Compatibility wrappers and typography helpers remain to avoid a broad rewrite. Light fallback surface tokens now use the original light palette. Timer completion guards, unrelated feature work, settings, and release metadata were retained. No reset, stash, or blanket checkout was used. A recoverable pre-edit patch and untracked-file copies are in `/tmp/ascent-before-home-refinement`.

The restored app built successfully before Home changes.

## Home

Home has a scoped day theme: warm neutral background, translucent white fills, low-contrast warm outlines, and no card blur or shadow. Other routes retain their restored presentation. Dark styling remains supported.

The top row groups date, streak and avatar; it wraps naturally at enlarged text sizes. Greeting/name and customization precede a full-width Ask Riya gateway. The redundant Mind Space heading is removed; its composer, latest note, View all, and expandable recent notes remain. Today stays open with understated tabs and highlighted active rows. Learning uses a single soft outlined surface, readable resume metadata, and accessible player controls. Life & Health uses one grouped surface with dividers; health cells stack when space or text scaling requires it.

## Validation

- Restored baseline Android debug APK: successful.
- Final Android arm64 debug APK: successful, `build/app/outputs/flutter-apk/app-debug.apk`.
- Flutter analyze: no issues.
- Focused Home, Mind Space, shared composer and chat regressions: 22 passed.
- Final populated Home renders at 390px/1x and 320px/2x: 2 passed; screenshots visually reviewed.
- Full regression suite: 444 passed.

Preview artifacts: `build/qa/home-refinement/home_390_1.0x.png` and `home_320_2.0x.png`.

The restored Analytics/Hydration layouts retain their pre-existing narrow-width limitations. Their render audit uses 480px for both themes, matching the previously documented legacy night constraint; those screens were not redesigned in this task.

APK was built, not installed. Home awaits user review; no further screen redesign is authorized yet.

## Files changed for this task

- Restoration: `lib/app/theme/app_theme.dart`, `lib/app/theme/surface_tokens.dart`.
- Scoped card treatment: `lib/shared/widgets/glass_surface.dart`.
- Home composition: `lib/features/home/home_screen.dart`.
- Home widgets: `home_theme.dart`, `home_header.dart`, `activity_hub_card.dart`, `activity_row_item.dart`, `learning_hub_card.dart`, `quick_modules_nav_hub.dart`, `thought_wall_home_preview.dart` under `lib/features/home/widgets/`.
- Checks: `test/home_day_layout_test.dart`, `test/home_modular_architecture_test.dart`, `test/mindspace_home_presentation_test.dart`; restored pre-migration composer/chat surface assertions in `test/renovation_ui_test.dart` and `test/thought_wall_chat_style_test.dart`, and aligned `test/day_surface_screen_audit_test.dart` with the restored legacy layouts.

Earlier changes in other screens were retained; they were not rewritten or redesigned.

## Small tint/outline revision

User-requested Home revision: Start streak and Ask Riya now have faint clay fills; Learning has a faint slate tint; Life & Health has a faint sage tint. These four day-mode outlines are black and remain 1px thick. Other card borders and dark styling retain their prior treatments. The Learning play-button glow is softer in day mode. A nullable fill override in GlassSurface allows local tints without changing other screens.

Files: `home_header.dart`, `learning_hub_card.dart`, `quick_modules_nav_hub.dart` under `lib/features/home/widgets/`, plus `lib/shared/widgets/glass_surface.dart`.

Revision checks: 11 focused tests passed; Flutter analyze reported no issues; populated Home preview visually reviewed. Final revision Android arm64 debug APK built successfully.

## Transparent surface/text refinement

Following the supplied reference flow, day Home now uses the existing cool light background and transparent interiors for Start, Ask Riya, Learning and Life & Health. Thin 1px outer outlines remain. Primary ink and secondary copy use neutral contrast suited to the background. Ask Riya has a more compact title/subtitle treatment; Learning has a single title line at ordinary text sizes, retaining two lines and stacked controls for enlarged text. Elapsed/total labels span the card. Health totals are more prominent and now follow the system text scale. No routes or behavior changed.

Changed files: `home_theme.dart`, `home_header.dart`, `learning_hub_card.dart`, `quick_modules_nav_hub.dart` in `lib/features/home/widgets/`.

Validation: 11 focused tests passed, Flutter analyze clean, rendered populated Home visually reviewed. Revision Android arm64 debug APK built successfully: `build/app/outputs/flutter-apk/app-debug.apk`.

## Device installation

Final Android arm64 release build succeeded: `build/app/outputs/flutter-apk/app-release.apk` (50.8 MB). Installed with `adb install -r` on the connected A142 device; result: Success. The existing `com.arun.ascent` installation was updated in place. Launch status: ok; running process confirmed. Installed version: 1.0.13, code 14. App data was not cleared.

## Warm background and playback controls

Home's stationary faint clay/brown background glows are restored. Today and Learning use consistent idle play controls with a soft clay fill, fine clay outline and clear triangle; active playback retains a filled clay pause control. View all uses a contrasting slate-blue foreground.

Changed files: `home_theme.dart`, `activity_row_item.dart`, `learning_hub_card.dart`, `thought_wall_home_preview.dart` in `lib/features/home/widgets/`.

Checks: 11 focused tests passed; Flutter analyze clean; populated Home preview reviewed. Android arm64 release APK built successfully and installed on the existing A142 device with `adb install -r` (Success), preserving app data.

## Thought Wall card parity

Thought Wall day cards now match Home's thought preview with a faint translucent white fill, a subtle neutral 1.2px outline, no shadow, and matching readable neutral content ink. Selected cards keep their stronger accent outline with a gentler tint. Existing card geometry, content, metadata, actions, gestures and dark surfaces remain.

Files: `lib/features/thought_wall/thought_wall_screen.dart` and the existing day-surface expectation in `test/thought_wall_chat_style_test.dart`.

Checks: 16 tests passed across card styling, selection feedback, archive/done and narrow/large-text layouts; Flutter analyze clean; day rendering reviewed. Release APK build successful; installed in place on the A142 device with `adb install -r` (Success), preserving app data.
