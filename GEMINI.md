# Gemini AI Assistant Rules for Ascent

1. **Branching**: Always develop on a feature branch (`feature/<name>`). Never commit unverified changes directly to `main`.
2. **Performance First**: Keep the Home screen lightning fast (<100ms render). No continuous GPS listeners, no heavy fluid animation loops, no multi-stream lag on Home.
3. **UI / UX**: Translucent glass containers with subtle 1px border. Deep soothing background. Tactile haptics on every interaction.
4. **AI Gateway**: Keep AI interaction centralized in the floating "Riya se Baat" button linking to `/ai-assistant`.
5. **Back Button**: Double-tap back on Home to exit, and back from other tabs reverts to Home tab first.
6. **Deployment**: Merge after self-audit with user approval, compile APK, and install on device via ADB.
7. **Preview Capping & Scalability**: Dashboard and Home preview lists (e.g. Today activities) must never grow unbounded or fill the full screen. Always cap preview items (e.g., max 4) with explicit "Show more / Show less" and "View all / Open board" navigation.
8. **CRUD Completeness & Cascading Deletion**: Any created entity (activities, tasks, reminders, routines) must provide full, intuitive Edit and Delete capabilities. Deleting an item must cascade cleanly across the entire system — removing associated reminders, scheduled notifications, running timers, and database references without leaving orphan reminders or notifications behind.
9. **Activity Classification Integrity**:
   - Simple **To-do** items (without an estimated target duration) must NOT have a focus timer clock or play button; they only offer completion toggles and edit/delete options.
   - **Timed / Duration** activities have dedicated countdown/stopwatch controls and focus timer sessions.
10. **Design Preservation Principle**: Visual redesigns and aesthetic enhancements must NEVER eliminate, obscure, or orphan existing functional entry points (e.g., Course Catalog switcher, syllabus viewer, or player sheets). All navigation flows must remain explicit, intuitive, and fully accessible.

