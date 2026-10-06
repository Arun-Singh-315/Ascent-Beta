# Agentic AI Workflow & Architecture Guidelines

## 1. Branching & Git Protocol
- **Always Branch First**: Never write changes directly to `main`. Always create a descriptive branch: `feature/<feature-name>`.
- **Self-Audit**: Before requesting merge, run `flutter test` and `flutter analyze`. Evaluate performance, frame rates, and responsiveness.
- **Merge to Main**: Only merge to `main` with user approval. Write clear, structured commit messages detailing exact changes.

## 2. Performance-First Mobile Architecture
- **Home Screen Zero-Lag Policy**: The Home screen is the heart of the application. It must render in < 100ms:
  - NO live GPS or location background listeners on Home.
  - NO continuous animation controllers (e.g. infinite fluid water waves) running on Home.
  - NO concurrent heavy multi-query aggregations on Home load.
  - Keep Home clean, lightweight, and view-first.
- **Dedicated Domain Screens**: Specialized or resource-intensive features (Hydration tracking, Walk GPS tracking, Thought Wall, Expense loggers) must live on dedicated screens/routes, NOT inlined into the Home screen.
- **Lightweight Online / Offline Balance**: Do not make the app sluggish by forcing multi-megabyte offline tile sets or heavy engines. If a lightweight online API/tile service is significantly faster, use it gracefully with friendly offline notifications.

## 3. UI / UX Design & Aesthetics
- **Transparent Glass Containers**: All primary cards should use translucent surfaces with subtle borders:
  - Surface: `context.bgSurface.withValues(alpha: 0.55)`
  - Border: `Border.all(color: context.divider.withValues(alpha: 0.6), width: 1.0)`
  - Rounded corners: `BorderRadius.circular(18)`
  - Soothing background smoothing.
- **AI Gateway ("Riya se Baat")**: All AI capabilities are centralized through a single, floating pill button named "Riya se Baat" that opens `/ai-assistant`. Do not clutter screens with redundant inline omnibars or copilot cards.
- **Tactile Haptics Everywhere**: Wire `HapticFeedback.lightImpact()` or `selectionClick()` to all cards, action buttons, bottom bar tabs, and floating actions.

## 4. Navigation & System Back Button Sync
- **No Accidental Exits**: Use `PopScope` on the main scaffold:
  - Pressing back from any secondary tab returns the user to the Home tab (Tab 0).
  - Pressing back on the Home tab triggers a 2-second double-tap exit guard with a discreet toast/snackbar.
  - Modal sheets and side drawers must dismiss before the route pops.
  - Use `Navigator.maybePop(context)` / `context.pop()` for sub-screens.

## 5. Build & Deployment
- Deploy via `/home/arunsinghvisen/Android/Sdk/platform-tools/adb`.
- Verify connected device via `adb devices`, compile latest APK, and install automatically when approved.
