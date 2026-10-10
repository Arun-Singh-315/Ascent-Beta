# Ascent — Complete Screen & Feature Inventory

**Version:** 1.0.2+3  
**Architecture:** Flutter 3.9+ / Riverpod / Drift SQLite / GoRouter

---

## 1. Master Feature & Screen Inventory

### 1. Core Shell & Navigation
- **Screen:** `MainScaffold` (`lib/shared/widgets/main_scaffold.dart`)
- **Route:** StatefulShellRoute wrapping tabs 0–4
- **Tabs:**
  - Tab 0: Home (`/home`)
  - Tab 1: Reminders & Alerts (`/reminders`)
  - Tab 2: Money Management (`/money`)
  - Tab 3: Momentum & Wellness (`/momentum`) *(To be replaced with Coming Soon)*
  - Tab 4: More Hub (`/more`)
- **Persistent Overlays:**
  - `LiveSessionBar`: Ticking live session widget pinned directly above the bottom navigation bar for active study, walk, or lecture timers.
  - `AscentDrawer`: Side drawer navigation providing direct shortcuts to Study Plan, Book Reader, DSA, Interview Prep, Pipeline, Today Board, Consistency, Vault, and Settings.
- **Back Navigation Policy:** Double-tap back on Home tab to exit application; back from any secondary tab reverts to Tab 0 (Home).

---

### 2. Home Dashboard (`HomeScreen`)
- **File:** `lib/features/home/home_screen.dart`
- **Route:** `/home`
- **Purpose:** Central executive overview of daily execution, learning progress, life balance, and reflections.
- **Entry Point:** Initial route after Splash and Auth.
- **Sub-Widgets & Components:**
  - `HomeHeader`: Date caption, greeting, user profile name, role micro-badge, interactive streak flame, and centralized Riya AI Gateway button (`/ai-assistant`).
  - `HomeAtmosphereBackground`: Stationary custom painter rendering dual atmospheric ambient glows.
  - `DayOneTutorialCard`: Dismissible onboarding tutorial explaining To-Dos vs Timed Focus, Riya AI Gateway, and Learning Hub.
  - `WelcomeBackBanner`: Cold-start welcome card displayed if user has been absent >3 days.
  - `StudyStreakMeterCard`: Dopamine-driven streak meter expandable by tapping the header flame icon.
  - `HomeDismissibleRemindersSection`: Horizontally swipeable reminders with 1-tap complete or dismiss.
  - `ActivityHubCard`: Primary Today execution level showing capped preview of top 4 activities, completion toggles, focus timer launches, and navigation to the full Task Board.
  - `LearningHubCard`: Secondary Level 2 card showing current enrolled course, active module, progress indicator, and 1-tap lecture focus player.
  - `QuickModulesNavHub`: Level 2 Life & Health card containing Medicine prescription doses, Hydration tracker with instant +250mL button, and Chai & Coffee Break footer. *(Currently contains Momentum challenge cell to be decoupled).*
  - `ThoughtWallHomePreview`: Level 3 self-talk reflections preview with quick link to Thought Wall.
- **Modals & Dialogs:**
  - `StreakCelebrationDialog`: Confetti-accompanied celebration popup when a streak milestone is reached.
  - `InAppReminderDialog`: Overdue reminder prompt shown on application resume.

---

### 3. Today Tasks & Activity Board (`TaskBoardScreen`)
- **File:** `lib/features/today/task_board_screen.dart`
- **Route:** `/today`
- **Purpose:** Full actionable task board with 3 tabs: Today, Others, and Completed.
- **Key Capabilities:**
  - Filter by priority (High, Medium, Low, All).
  - Add Activity modal (`AddActivitySheet`) with support for To-do items, Timed Focus items, and Flexible items.
  - Classification integrity: Simple to-dos only show completion toggles; duration activities show focus timer clock controls.
  - Cascading deletion and undo snackbars.

---

### 4. Reminders & Alerts (`RemindersScreen`)
- **File:** `lib/features/reminders/reminders_screen.dart`
- **Route:** `/reminders`
- **Purpose:** Central notification center for all system, activity, study, hydration, and medicine reminders.
- **Key Capabilities:**
  - Active and Completed reminder sections.
  - Priority badges, overdue indicators, category filtering.
  - Instant toggle, delete, snooze, and create custom alert.

---

### 5. Money Management (`MoneyScreen`)
- **File:** `lib/features/money/money_screen.dart`
- **Route:** `/money`
- **Purpose:** Financial discipline companion with daily budget, monthly burn tracking, and category breakdown.
- **Key Capabilities:**
  - Daily available spend calculation vs monthly limit.
  - Financial copilot summary card.
  - Transaction history list by date.
  - Modal sheets: `AddTransactionSheet`, `BudgetSettingsSheet`.

---

### 6. Momentum & Fitness Protocol (`MomentumScreen` — RETIRED)
- **File:** `lib/features/momentum/momentum_screen.dart`, `momentum_onboarding_screen.dart`
- **Route:** `/momentum`, `/momentum-onboarding`
- **Status:** **RETIRED BY EXPLICIT REQUEST.**
- **Action:** Replace entirely with a clean `MomentumComingSoonScreen` while preserving Tab 3 navigation.

---

### 7. More Tools & Hub (`MoreScreen`)
- **File:** `lib/features/more/more_screen.dart`
- **Route:** `/more`
- **Purpose:** Organized visual directory of all secondary and specialized features.
- **Sections:**
  - **Learning & Mastery:** Study Plan & Course Catalog, DSA Problem Tracker, Kindle Book Reader.
  - **Career & Applications:** Application Pipeline, Interview Prep, Resume Vault.
  - **Intelligence & Copilot:** AI Life Assistant (`/ai-assistant`), Thought Wall (`/thought-wall`).
  - **Life & Sanctuary:** Medicine Tracker, Hydration, Chai & Coffee Break, Outdoor Walk Tracker.
  - **System & Metrics:** Consistency Heatmap, Analytics & Velocity, Settings.

---

### 8. Learning Hub & Course Catalog (`CourseCatalogScreen`, `StudyPlanScreen`, `LectureFocusPlayerScreen`)
- **Files:** `lib/features/study_plan/`
- **Routes:** `/study-plan`, `/study-plan/course/:id`, `/learning`
- **Purpose:** Structured curriculum mastery with hierarchical course catalog, module syllabus, lecture tracking, and audio/focus timer player.
- **Key Capabilities:**
  - Pre-seeded course data (Full Stack Engineer, System Design, DSA).
  - Module and lecture progress indicators.
  - Floating bottom player sync with `LiveSessionBar`.
  - Sheets: `AddCourseSheet`, `ModuleLectureEditorSheets`, `LectureFocusPlayerSheet`.

---

### 9. Focus Timer (`FocusScreen`)
- **File:** `lib/features/focus/focus_screen.dart`
- **Route:** `/focus`
- **Purpose:** Fullscreen distraction-free countdown timer with ambient soundscapes (Campfire, Library, Lofi, Rain, Zen River, Drone).
- **Key Capabilities:**
  - Duration presets (15, 25, 45, 60 min).
  - Live session background persistence.
  - Category assignment and automatic task linking.

---

### 10. Chai & Coffee Break Sanctuary (`ChaiBreakScreen`)
- **File:** `lib/features/chai_break/chai_break_screen.dart`
- **Route:** `/chai-break`
- **Purpose:** 5-minute rejuvenating mindfulness break designed around tea/coffee brewing rituals.
- **Key Capabilities:**
  - Interactive steaming cup custom painter.
  - 4-7-8 and Box breathing guides (`MindfulBreathingGuide`).
  - Brewing recipe guides (Masala Chai, Filter Coffee, Green Tea, Espresso).
  - 7 offline ambient soundscape loops with volume controls.
  - `FlowResumeCard` and `ChaiBreakResumeDock` to cleanly return to interrupted work.

---

### 11. Thought Wall / Mind Space (`ThoughtWallScreen`)
- **File:** `lib/features/thought_wall/thought_wall_screen.dart`
- **Route:** `/thought-wall`
- **Purpose:** Unfiltered "Me to Me" self-talk, sparks, daily wins, and letters to future self.
- **Key Capabilities:**
  - Chat-style message bubbles with category pills (Me to Me, Spark, Raw Thought, Win, Future Me).
  - WhatsApp and SMS direct sharing for single or batch notes.
  - Bottom input composer with category picker and reflection prompts.

---

### 12. Hydration Tracker (`HydrationScreen`)
- **File:** `lib/features/hydration/hydration_screen.dart`
- **Route:** `/hydration`
- **Purpose:** Water intake tracking with daily goal progress and container presets (250mL, 500mL, 750mL).
- **Key Capabilities:**
  - Animated wave water fill visual card (`AnimatedWaterCard`).
  - 1-tap quick add from Home and Quick Action popup (`HydrationPopupDialog`).

---

### 13. Medicine & Prescriptions (`MedicineScreen`)
- **File:** `lib/features/medicine/medicine_screen.dart`
- **Route:** `/medicine`
- **Purpose:** Multi-day prescription tracker with scheduled daily dose logs, compliance statistics, and automatic notification sync.

---

### 14. Outdoor Walk Tracker (`WalkScreen`)
- **File:** `lib/features/walk/walk_screen.dart`
- **Route:** `/walk`
- **Purpose:** GPS-based walking tracker with live map route polyline, distance (km), pace, and background service persistence.

---

### 15. Job Application Pipeline (`PipelineScreen`, `CardDetailScreen`)
- **File:** `lib/features/pipeline/pipeline_screen.dart`
- **Route:** `/pipeline`, `/pipeline/:id`
- **Purpose:** Kanban pipeline across 5 stages (Wishlist, Applied, Interviewing, Offer, Rejected) with notes, salary, deadlines, and recruiter email parser (`EmailInviteParserSheet`).

---

### 16. DSA Problem Tracker (`DsaScreen`)
- **File:** `lib/features/dsa/dsa_screen.dart`
- **Route:** `/dsa`
- **Purpose:** LeetCode problem log categorized by topic (Arrays, Graphs, Trees, DP), difficulty, solve time, and revisit bookmarks.

---

### 17. Interview Prep (`InterviewPrepScreen`)
- **File:** `lib/features/interview_prep/interview_prep_screen.dart`
- **Route:** `/interview-prep`
- **Purpose:** 2-tab preparation tool with countdown to upcoming interview rounds and question bank with STAR format notes.

---

### 18. Consistency Tracker (`ConsistencyScreen`)
- **File:** `lib/features/consistency/consistency_screen.dart`
- **Route:** `/consistency`
- **Purpose:** Visual GitHub-style activity heatmap, historical streak counters, and daily completion logs.

---

### 19. Resume Vault (`ResumeVaultScreen`)
- **File:** `lib/features/resume_vault/resume_vault_screen.dart`
- **Route:** `/resume-vault`
- **Purpose:** PDF version management with role tagging, upload date, and in-app document viewing via `flutter_pdfview`.

---

### 20. Kindle Book Reader (`KindleBookReaderScreen`)
- **File:** `lib/features/book_reader/kindle_book_reader_screen.dart`
- **Route:** `/book-reader`
- **Purpose:** Reading companion for non-fiction and technical books, tracking pages read, active sessions, and book quotes.

---

### 21. Analytics & Velocity (`AnalyticsScreen`, `SeriesReportCardScreen`)
- **File:** `lib/features/analytics/analytics_screen.dart`
- **Route:** `/analytics`, `/analytics/series/:id`
- **Purpose:** Historical velocity charts (`fl_chart`), study-to-job conversion rates, and series report cards.

---

### 22. AI Assistant & Companion (`AiAssistantScreen`)
- **File:** `lib/features/ai_assistant/ai_assistant_screen.dart`
- **Route:** `/ai-assistant`
- **Purpose:** Central conversational assistant (defaults to Riya, user-configurable to Jarvis, Aria, Nova) providing grounded productivity coaching, natural-language activity logging, and day planning.

---

### 23. Settings (`SettingsScreen`)
- **File:** `lib/features/settings/settings_screen.dart`
- **Route:** `/settings`
- **Purpose:** User profile configuration, Day/Night/System theme toggle, assistant identity selection, notification switches, and full database reset.

---

### 24. Onboarding & Splash (`SplashScreen`, `OnboardingShell`, `LoginScreen`)
- **Files:** `lib/features/splash/`, `lib/features/onboarding/`, `lib/features/auth/`
- **Routes:** `/`, `/onboarding`, `/login`
- **Purpose:** Initial setup flow capturing name, target role, daily study target, and initializing baseline SQLite tables.
