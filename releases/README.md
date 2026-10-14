# Ascent Android builds

Current phone build: **Ascent-1.0.11-12-arm64.apk**, package `com.arun.ascent`, version 1.0.11 (12), database schema 16. This APK targets ARM64, verified on the Nothing A142. Full regression suite: **392 passed**, followed by a passing 11-test final selection/timer boundary batch; static analysis is clean. The combined Home/selection/timer Android suite passed. [Current implementation and verification](../docs/MIND_SPACE_IMPLEMENTATION.md).

APKs are ignored by Git and retained in this workspace, with adjacent SHA-256 files. The 1.0.6 (7) and 1.0.7 (8) builds remain available as historical artifacts; installing an older APK over a newer database is not a verified rollback procedure. Use a compatible backup rather than resetting data.

Native Learning/Focus controls and cold-process alarm Snooze/Done recovery were verified on the connected Nothing A142 using a separate temporary QA package. The test packages were removed afterward. Quiet reminder notifications remain the default; Alarm mode is optional.

Version **1.0.8 (9) installed successfully** over the existing app on the Nothing A142 on 12 October 2026. Cold launch and installed metadata verified. SHA-256: `8e0e19f63a545e90fd5e9ac936644a86ef946eba18f3ca7c42e44cddac910e2f`.

Version **1.0.9 (10) installed successfully** on the Nothing A142 on 12 October 2026. Installed metadata and cold launch verified. Glass polish covers Riya messages/action receipts, reminder preview/feedback/options, and native/in-app alarm controls. SHA-256: `83988cf8cf85e06b688685bd738271ad33a809e1c9e775cc14992a4e275c7751`.

Version **1.0.10 (11) installed successfully** over the regular app on the Nothing A142 on 13 October 2026. Cold launch and installed metadata verified. This release adds the focused Learning/Medicine conversation pass; no additional feature area was started. SHA-256: `210f8cc7d486a7bba591e14fecf70b7546fb412800efcee8ba02511c39c82531`.

Version **1.0.11 (12) installed successfully** over the regular app on the Nothing A142 on 14 October 2026. Cold launch, installed metadata and actual Home screenshot verified. Includes compact recent Mind Space, four-note expansion, direct wall navigation, profession-row customization, visible selection actions with successful-save exit, quiet archive/running surfaces and automatic set-duration task completion. Existing user notes remained visible after the update. Challenge calendar is queued for the next separate feature. SHA-256: `40631d619a2c937982edbe84f379f5ad1b27b522b8e9fb5e4008ea8d1529ca56`.
