# Ascent Android builds

Current build: **Ascent-1.0.9-10.apk**, package `com.arun.ascent`, version 1.0.9 (10), database schema 15. Full regression suite: **299 passed**. Flutter analysis: clean. [Glass UI polish and verification](../docs/renovation/GLASS_POLISH_RESULTS.md).

APKs are ignored by Git and retained in this workspace, with adjacent SHA-256 files. The 1.0.6 (7) and 1.0.7 (8) builds remain available as historical artifacts; installing an older APK over a newer database is not a verified rollback procedure. Use a compatible backup rather than resetting data.

Native Learning/Focus controls and cold-process alarm Snooze/Done recovery were verified on the connected Nothing A142 using a separate temporary QA package. The test packages were removed afterward. Quiet reminder notifications remain the default; Alarm mode is optional.

Version **1.0.8 (9) installed successfully** over the existing app on the Nothing A142 on 12 October 2026. Cold launch and installed metadata verified. SHA-256: `8e0e19f63a545e90fd5e9ac936644a86ef946eba18f3ca7c42e44cddac910e2f`.

Version **1.0.9 (10) installed successfully** on the Nothing A142 on 12 October 2026. Installed metadata and cold launch verified. Glass polish covers Riya messages/action receipts, reminder preview/feedback/options, and native/in-app alarm controls. SHA-256: `83988cf8cf85e06b688685bd738271ad33a809e1c9e775cc14992a4e275c7751`.
