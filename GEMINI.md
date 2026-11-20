# Gemini assistant rules for Ascent

**[CLAUDE.md](CLAUDE.md) is the single source of truth** for what Ascent is (a premium, offline-first personal OS), the "never later" user-ease principle, the Apple-premium design language, navigation, the hero surfaces (Home, Things Hub, Thought Wall), component contracts and engineering rules. [AGENTS.md](AGENTS.md) adds device-safety and shared-control rules. Follow both. If anything conflicts, CLAUDE.md wins. Update the conflicting file in the same change.

Gemini-specific reminders (all restate CLAUDE.md, do not diverge):

1. **Branching:** develop on `feature/<name>`; merge to `main` only when verified and asked.
2. **Performance:** Home renders fast; no continuous GPS or off-screen animation loops.
3. **Assistant identity:** never hardcode a name. Read the configured assistant name (default `AppConstants.assistantName`) everywhere; the gateway route is `/ai-assistant`.
4. **Back button:** double back on Home exits; back from other tabs returns to Home first.
5. **Preview caps:** Home/dashboard previews show at most 4 items with "Show all".
6. **CRUD and cascade:** everything created can be edited and deleted; deletes remove linked reminders, notifications, timers and references.
7. **Activity classification:** plain to-dos have no timer; timed activities have timer controls.
8. **Design preservation:** redesigns never remove or hide functional entry points.
9. **No dead code:** removing a feature purges its code and tests in the same change.
10. **Tests first:** features are done only when tests (empty, 1, 100+ items, light/dark, 320 px at text scale 2.0) pass.
11. **Tokens only:** no inline colors, font sizes, paddings or radii in feature code.
12. **One input = one container:** a single enclosure for every text field and composer; no nested bordered boxes, no Material focus outlines.
13. **Temporary plans:** delete them after the work is verified unless asked to keep them.
