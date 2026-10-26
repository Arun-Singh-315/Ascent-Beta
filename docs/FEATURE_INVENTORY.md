# Ascent feature inventory

Current source map · reviewed 12 October 2026. Route definitions in `lib/app/router.dart` are authoritative. This inventory describes available entry points, not guaranteed CRUD coverage or completion of the proposed plans.

| Area | Entry points | Source under `lib/features/` |
| --- | --- | --- |
| Workspace entry | `/`, `/onboarding`; local Quick Start/profile rules | `splash/`, `onboarding/` |
| Home | `/home`; inline notes, activity/learning previews, everyday tools, Riya gateway | `home/` |
| Today | `/today`; activities and task board | `today/` |
| Reminders | `/reminders`; upcoming/overdue records, notifications and optional alarms | `reminders/` |
| Money | `/money`; transactions, budgets and savings goals | `money/` |
| More | `/more`; additional tool destinations | `more/` |
| Challenges | `/momentum`; current challenge UI and legacy onboarding route aliases | `momentum/`, `challenge/` |
| Learning | `/study-plan`, `/study-plan/course/:id`, `/learning`; catalog, syllabus, module/lecture editing and player | `study_plan/` |
| Focus | `/focus`; timed sessions and controls | `focus/` |
| Mind Space | `/thought-wall`; thoughts, pinning, editing, archive, sharing and Todo/Reminder conversion | `thought_wall/` |
| Breaks | `/chai-break`; brewing guidance, soundscapes, breathing and break/session return behavior | `chai_break/` |
| Hydration | `/hydration`; water logging and goals | `hydration/` |
| Medicine | `/medicine`; prescriptions, schedule and logs | `medicine/` |
| Walking | `/walk`; tracking and session history | `walk/` |
| Applications | `/pipeline`, `/pipeline/:id`; application records and email invite parsing | `pipeline/` |
| DSA | `/dsa`; problem tracking | `dsa/` |
| Interview preparation | `/interview-prep`; questions and preparation | `interview_prep/` |
| Consistency | `/consistency`; recorded consistency history | `consistency/` |
| Resume Vault | `/resume-vault`; supported attachment management | `resume_vault/` |
| Reader | `/book-reader`; PDF reading and note capture | `book_reader/` |
| Analytics | `/analytics`, `/analytics/series/:id`; tracked progress and series reports | `analytics/` |
| Riya | `/ai-assistant`; chat, supported local commands and verified action receipts | `ai_assistant/`, with command services in `core/ai/` |
| Settings | `/settings`; preferences and help entry points | `settings/` |
| Workspace backup | `/backup`; export, restore preview and recovery | `backup/` |

Riya's Home Ask button opens a compact chat sheet using the same saved conversation as `/ai-assistant`. Local Todo/Promise commands ask for a missing title or day, show inline Save/Delete reviews, and return live record cards. Todo cards offer completion, rename, rescheduling and deletion; Promise cards offer check-in, rename, start-day changes, pause/resume and deletion. Existing detail/session sheets handle full schedules and timed or milestone tracking. Private Promises stay masked and are managed through the Promises screen. These commands use deterministic offline parsing, transaction receipts and retryable notification effects; they do not require an online model.

The shell has four branches: Home, Reminders, Money and More. Challenges are a separate routed tool, not a fifth shell branch. No `/login` route or credential provider is required to enter the local workspace.

Replaced Home planners/previews, the demo login, old new-day dialog, prototype insight engine and superseded break resume widgets were removed during cleanup. Current Home uses `ThoughtWallHomePreview`; current break screens and the shared `LiveSessionBar` retain active lifecycle behavior.

Do not remove legacy database tables or migration code based solely on this screen map. Persisted data, backup compatibility and native alert lifecycle are separate concerns. See the [architecture](APP_ARCHITECTURE.md) and [documentation index](README.md) for those references and future plans.
