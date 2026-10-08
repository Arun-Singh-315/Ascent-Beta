# Gemini AI Assistant Rules for Ascent

1. **Branching & Lifecycle**: Always develop on a feature branch (`feature/<name>`). Never commit unverified changes directly to `main`. When a feature or set of fixes is verified and completed with all tests passing, merge the feature branch cleanly into `main`, checkout `main`, and create a new feature branch (`feature/<name>`) for the next task.
2. **Performance First**: Keep the Home screen lightning fast (<100ms render). No continuous GPS listeners, no heavy fluid animation loops, no multi-stream lag on Home.
3. **UI / UX**: Translucent glass containers with subtle 1px border. Deep soothing background. Tactile haptics on every interaction.
4. **AI Gateway**: Keep AI interaction centralized in the AI Assistant button (dynamically reflecting the configured assistant identity name, defaulting to Riya) linking to `/ai-assistant`.
5. **Back Button**: Double-tap back on Home to exit, and back from other tabs reverts to Home tab first.
6. **Deployment & Merge**: Merge verified feature branches into `main`. Compile APK and install on device via ADB when requested.
7. **Preview Capping & Scalability**: Dashboard and Home preview lists (e.g. Today activities) must never grow unbounded or fill the full screen. Always cap preview items (e.g., max 4) with explicit "Show more / Show less" and "View all / Open board" navigation.
8. **CRUD Completeness & Cascading Deletion**: Any created entity (activities, tasks, reminders, routines) must provide full, intuitive Edit and Delete capabilities. Deleting an item must cascade cleanly across the entire system — removing associated reminders, scheduled notifications, running timers, and database references without leaving orphan reminders or notifications behind.
9. **Activity Classification Integrity**:
   - Simple **To-do** items (without an estimated target duration) must NOT have a focus timer clock or play button; they only offer completion toggles and edit/delete options.
   - **Timed / Duration** activities have dedicated countdown/stopwatch controls and focus timer sessions.
10. **Design Preservation Principle**: Visual redesigns and aesthetic enhancements must NEVER eliminate, obscure, or orphan existing functional entry points (e.g., Course Catalog switcher, syllabus viewer, or player sheets). All navigation flows must remain explicit, intuitive, and fully accessible.
11. **Feature Deprecation & Thorough Code Purging (No Dead Code)**: When any feature or module is removed or replaced, perform an end-to-end clean purge across the entire codebase. Completely eliminate associated screens, widgets, routes, DAOs, table definitions, providers, mock data seeders, and unused assets. Never leave behind dead code, unused imports, zombie references, or commented-out ghosts. Accompany every removal with comprehensive test updates to keep the test suite 100% clean and passing.
