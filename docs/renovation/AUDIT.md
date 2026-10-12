# Ascent · Mind Space renovation audit

11 October 2026. Baseline: HEAD `011209e` plus existing uncommitted reflections work, version1.0.5+6. This audit precedes renovation edits. Source observations are distinguished from runtime checks.

## Executive assessment / evidence limits

The app has substantial local functionality and useful Task/Focus/Learning/Challenge connections. Highest priority: Riya auto-executes proposed writes, swallows execution errors, and displays green confirmation even for unsupported actions. Streak urgency affects new users; the prior-day preference never advances and the midnight watcher is never started. Theme restoration needs a preferred reference, rather than blindly reverting the user's previous no-blue/no-violet request.

Previous iteration verified29 focused tests, analysis, release build and installation. This is not a full-suite result for this renovation. The last device screenshot showed incomplete Target Companies onboarding. Current `adb devices` lists no devices. All production screens below are **runtime unverified in this renovation**. No personal profile or records have been changed to bypass onboarding. Model/widget checks will be recorded in RESULTS.md.

## A. Architecture / inventory

- Flutter/Dart; Riverpod providers/notifiers; go_router root navigator with four retained tabs Home/Reminders/Money/More, leaf screens pushed over shell. Source: `lib/app/router.dart`, `lib/shared/widgets/main_scaffold.dart`. Back from another tab returnsHome; Home double-back exits.
- Drift SQLite schema12 with migration branches1–12, 33 declared table classes and22 DAOs (`lib/core/database/app_database.dart`). SharedPreferences also holds settings, Learning Hub nested courses/modules/lectures, streak seconds and walkthrough flags. Nested learning courses and DB course records are distinct ownership domains.
- No hosted backend/remoteLLM integration found. `lib/core/ai/ai_service.dart` is deterministic parsing/rules; chat persistsSQLite. Runtime GoogleFonts, OpenStreetMap tiles and selectable audio can depend on internet. Core records are local.
- Focus notifier (`core/providers/time_tracking_provider.dart`) ticks eachsecond, persists heartbeat each5seconds, restores sessions, distinguishes timed tasks and handles completion/cascade cleanup. Learning notifier (`core/learning_hub/learning_hub_provider.dart`) has separate lecture timer and persisted course objects. Chai provider has timer/audio/brewing/resume. Walk service tracks GPS and persisted sessions.
- Notifications: local plugin, timezone initialization, permissions, exact/inexact scheduling, follow-ups, category channels, ongoing controls, payload routing (`core/notifications/notification_service.dart`, `main.dart`). Scheduling errors caught internally; storing a reminder does not prove delivery. Startup requests notification permissions.
- Splash gates on profile/onboarding. Auth provider has hardcoded arn/1234; Login exists but isn't routed, Splash doesn't authenticate. This is not secure account authentication. Local database has no user tenancy; don't claim multi-user isolation/cloud sync.
- Insight/Series engines derive local progress. No event analytics or measured retention/search/latency baseline found.43 test files at audit time. No performance or accessibility compliance certification exists.

### Every screen and important interaction / concrete UX audit

Source paths below are under `lib/features/`; shared source mentioned explicitly. State/edge tests are proposed unless RESULTS.md records execution.

| Screen, route, source | Existing behavior → issue → correction → benefit → validation |
|---|---|
| Splash `/`, splash/splash_screen | Version/profile check/animation, minimum1.4s → delayed entry/profile failure routes onboarding → review optional profile (approval) → faster access → fresh/returning/restart |
| Onboarding `/onboarding`, onboarding/onboarding_shell | Name/role/company selection and profile save → company selection blocks casual daily tools (previous screenshot) → optional career setup (approval) → access without career decisions → fresh/save/restart |
| Login unrouted, auth/login_screen | Local credential form → hardcoded credentials/no guards → decide device-lock versus real account boundary (approval) → honest privacy → threat review |
| Home `/home`, home/home_screen + widgets | Header/streak, conditional reminder above Activity, Learning, inline MindSpace, health/challenge/PlanMyDay → inherited outlined field/zero-day urgency → explicit line decoration/calendar state → calm accurate overview → empty/populated/day/theme widgets |
| Today `/today`, today/task_board_screen + add_activity_sheet | Overdue/today/upcoming/completed, priority, CRUD, timed/quick task, Focus links → dense forms/hidden secondary actions → concise contextual labels, preserve timed-completion rules → fewer mistakes → CRUD/locking/cascade |
| Reminders `/reminders`, reminders/reminders_screen + widgets/in_app_reminder_dialog | Date/time/repeats/edit/activate/deleteUndo/overdue start-dismiss/linkedTask → device scheduling status unclear → distinguish saved versus alert scheduling → trust → past/repeat/denied/overlap/device delivery |
| Money `/money`, money/money_screen + add_transaction_sheet + budget_settings_sheet | Transactions/trends, periods, budget/goals/income/expense/category/account → appbar+ and AddExpense and empty add duplicate → one body primary; separate savings action → clear entry → CTAcount/ledgerCRUD |
| More `/more`, more/more_screen | Grouped feature hub/live summaries → technical descriptions/many sections → plain labels, later searchable help → easier discovery → route/textscale |
| ThoughtWall `/thought-wall`, thought_wall/thought_wall_screen + drop_thought_sheet | Notes/Promises, search/filter/pin/done/archive/deleteUndo/share/edit/copy/selection/bulkTodo/reminder/list/challenge → edit/copy menu duplicates, Promise top+input, raw text → single hierarchy/quote treatment/topPromise → readable messages → quote/duplicates/longtext/selection/Undo |
| Challenges `/momentum` plus legacy aliases, momentum/momentum_screen + challenge/presentation | Multi-challenge chooser/create/Home selection/status/archive/delete/history/amend → add entry duplication possible by state → one visible primary/context; preserve per-goal proof → clear selection → independentproof/persistedchoice |
| Focus `/focus`, focus/focus_screen | Study/Break/Sessions, task/start/pause/resume/switch/complete/history → competing assistant timer must not overwrite active session → active conflict guard → reliable continuation → heartbeat/restart/OS controls |
| Learning `/learning`, study_plan/lecture_focus_player_screen + sheet | Lecture selection/play/pause/complete/courses → separate Focus vslecture lifecycles → keep distinction explicit → no doublecounting → lifecycle/proof/notifications |
| Courses `/study-plan`, study_plan/course_catalog_screen + add_course_sheet | Catalog/CRUD/reader/course choice → DB and nested course representations coexist → establish ownership before search → correct data → multi-course/delete |
| Course `/study-plan/course/:id`, study_plan/study_plan_screen + module_lecture_editor_sheets | Module/lecture filters/edit/delete/reorder/course switch → dense controls/longtitles → progressive actions → readable learning → largecourse/textscale |
| Reader `/book-reader`, book_reader/kindle_book_reader_screen | Built-in study/PDF picker/themes/task/reflection capture → useful existing links should retain context; files mayfail → recoverable picker/capture → lessretyping → filefailure/capturedcontent |
| Chai `/chai-break`, chai_break/chai_break_screen + widgets |5/10/15m, music/breathing/recipes/finish/resume/thought → browncup already stable, continuous steam ignores motionpref → reducedmotion now, layoutreview later → calm accessible break → audio/recipe/resume/motion |
| Hydration `/hydration`, hydration/hydration_screen + popup | Goal/quicklogs/history/delete/nudges → daychanges/permissioncopy need consistency → day refresh/alertstate → accurategoal → waterCRUD/day/denied |
| Medicine `/medicine`, medicine/medicine_screen | Prescription/dosetimes/completion/history/delete → dose-task sync exists, delivery unverified → preserve sync/clarify alerts → reliable schedule → dose/task/device |
| Walk `/walk`, walk/walk_screen | GPS/map/start/pause/resume/finish/discard/notes/history/goals/backgroundguide → online tiles/location/battery restrictions → actionable offline/perms recovery → usable tracking → persistence/denied/outdoor |
| Pipeline `/pipeline`, pipeline/pipeline_screen + email_invite_parser_sheet | SearchKanban/stagemove/CRUD/pasted recruiter parsing → untrusted pastedtext must not trigger AI actions → parsed data only → safe workflow → parse/stage/longtext |
| Application `/pipeline/:id`, pipeline/card_detail_screen | CRUD/copyURL/notes/linkedTask/prep → unchecked integer route parse → validate missing/invalidIDs → safedeep links → invalid/deletedrecord |
| Interview `/interview-prep`, interview_prep/interview_prep_screen | Searchquestion/company/topic/CRUD/practice/master/scheduledinterviews/applicationcontext → assistant guesses broad preparation activity → offer actionchoice → usercontrol → intent/no-write/bankCRUD |
| DSA `/dsa`, dsa/dsa_screen | Problems/topic/difficulty/revisit/delete/study → icondelete/long forms → semantics/validation → clearerpractice → filter/CRUD/textscale |
| Consistency `/consistency`, consistency/consistency_screen | Logs/calendar/study presence → separate DB and prefs streaksources → explicitly synchronize establishedrule → trustworthy progress → missingdays/calendar |
| Resume `/resume-vault`, resume_vault/resume_vault_screen | File/version/role/notesautosave/share/open/delete → unavailablepaths → recover without losingmetadata → usefulvault → picker/open/sharefailure |
| Analytics `/analytics`, analytics/analytics_screen | Study/breaktotals/seriescreate/pipelinecharts → unavailable async sometimes treatedzero → loading/error distinction → accurateinsights → empty/error/history |
| Series `/analytics/series/:id`, analytics/series_report_card_screen | Pace/velocity/consistency/addlinkedtask → uncheckedIDs/absentrecord → validatecontext → reliabledrilldown → engine/missingID |
| Riya `/ai-assistant`, ai_assistant/ai_assistant_screen | Chat/historyclear/chips/parserreads+writes/cards/Activity-Learningnav → errorsswallowed/auto-writes/allgreen/40dpsend → confirmation/result reporting/48dpalignment → trust → failure/duplicates/intent/widget |
| Settings `/settings`, settings/settings_screen | Profile/theme/goals/companies/notifs/guides/JSONbackuprestore/reset/tour → consequential restore/reset, deviceperms → retainconfirmations/auditexport coverage → safeownership → backup/theme/permission |

The generated source inventory appendix was removed during repository cleanup because it described the pre-renovation tree. Important modal/picker interactions: task add/edit/detail/delete; thought edit/Promise duration; reminder date/time/repeat/bulk; challenge create/amend/archive/delete; course/module/lecture editors/player; expense/budget/savings; question/interview/schedule; DSAlog; application/emailparser; resumeupload/delete; watergoal; prescription; walkfinish/backgroundguide; readercapture/filepicker; Homeplanner/streakdetails/celebration; settingsimport/reset/perms; tour/help; overdue/newday dialogs; native share/file/date/time pickers. Native platform surfaces remain unverified.

Shared state gaps: Home thought loading/error disappears; Riya queries turn failures into empty records; Money exposes raw exceptiontext; some insight async values defaultzero; notification failures swallowed; Home draft memoryonly. Reuse actual loading/error patterns in Focus/Reminders/Walk/Challenge. Screen-reader labels/textscale need verification; custom wall menu26dp and AI send40dp are too small. App portraitlocked; tablet/landscape isn't proven. Blur/continuousmotion need profiling; repaintboundaries do not prove frame rate.

### Design tokens / historical evidence

`lib/app/theme/{app_theme,color_tokens,glass_theme,text_styles,dimension_tokens}.dart` provides overlapping token layers, Inter/PlusJakarta and featurefonts. Theme InputDecoration explains Home's inherited outline. Home atmosphere aliases `shared/widgets/ascent_atmosphere.dart`. Commits98d1b4f/7c93a8f/5e43a56/currentHEAD show daybase#F4F3F8, translucent fills and radialclay/secondary glows; cap.18/.14 predates this renovation. Prior reflections warm substitutions removed blue/violet. Proposal for approval: preserve historic geometry/base/translucency, compare warmsecondary intensity with preferred screenshot. Don't silently restore blue or replace palette. Runtime fonts require offlinefallback/bundling review.

## B. All16 feedback matrix

|#|Currentissue|Correction / source|Priority|Verification / auditstatus|
|---|---|---|---|---|
|1|Chai layout busy, continuousmotion|chai_break/widgets/steaming_cup_painter motion; approvedlayoutlater|P2|Warmstablecup/motion/audio; partialpriorwork|
|2|Riya swallowederrors/autowrites/allgreen/no registry|core/ai + ai_assistant result/confirmation; approved registry|P0/P1|No false success, validated idempotentwrites; incomplete|
|3|Conditional Home preview already aboveActivity|home_screen + home_dismissible_reminders_section|P1|Empty no space, readonlynavigate; priorwidgettested/reverify|
|4|Money competingAdd controls|money/money_screen onebodyprimary|P1|OnevisibleexpenseCTA; notfixed|
|5|Rawthoughts|Shared quotepresentation + thought_wall_screen|P2|Quoteonce/multiline/emoji; notfixed|
|6|Long firstuse paragraphs|shared/widgets/feature_guide structuredshortsteps|P2|Once/replay/scanable; partial|
|7|40dpsend/uneveninputs/globalHomeborder|AI/Wall/Home composers|P1|48dp/disabled/multiline/themes/textscale; notfixed|
|8|Wall edit/copy repeatedmenu|thought_wall_screen hierarchy|P1|Directcommon/secondarymenu/Undo; notfixed|
|9|Preferred daywallreference unresolved|glass_theme/sharedatmosphere historicalreview|P1|Chosenreference/no-blue preserved; awaitingreview|
|10|Firstdayrisk/stalepriorstreak|core/streak + Homeheader/meter|P0|Fresh/day1/active/broken/rescue/midnight; notfixed|
|11|Home historicbase preserved, glowchanges needreference|home_atmosphere/glass_theme|P1|Reviewedatmosphere, noexcesswhite; awaitingreview|
|12|Home line inherits filled outline|home/widgets/thought_wall_home_preview|P1|Transparent/nooutline/clayfocusline; notfixed|
|13|Unevensend/Promise repeatedbesideinput|AI/Wall composers|P1|Aligned48dp/topPromiseonly; notfixed|
|14|Broadparser guessespreparation action|core/ai/ai_service|P1|Offeractionchoice/noarbitrarywrite; notfixed|
|15|Reminderbodyfont alreadyconsistent, headercrowded|thought_wall_screen presentation/hierarchy|P2|Long/short/multiline/content preserved; partial|
|16|Generichelprepeatsforcasualtext|core/ai/ai_service shorttone/limitations|P2|Appropriate greeting/humor, noboundaryviolations; notfixed|

## D. Feature connections

Existing: Thought→Todo uses transactional reuse and notes marker thought_id (notFK); selectedThoughts→individual or numberedlistreminder; Promise→Task+dailyreminders with update/completionsync; Task→Reminder via linkedTaskId; Task→Focus via activityreference→timedcompletion→linkedThought; Application→Task/interviewprep; Phase/Series→Task→paceanalytics; Learning/Focus→Challengelinks→proofevents→progress→selectedHome; MedicineDose→Task; Reader→Task/Thought; Expense→Category/Budget/periodsummary; chatDAOwrites→providerstreams→UI.

Proposed: local thoughtretrieval, durable provenance replacing notesmarkers (migration), reminder source links, optional completionreflection, interviewintention→chosenaction, localuniversalsearch, alert schedulingresult/retry. Preserve standaloneworkflows; no automatic redundant objects or forced wizard.

## E. Riya matrix / actual baseline

Y describes app storage/UI, not assistant support. Filter means existing context search, not universal search.

|Feature|Read|Create|Edit|Delete|Search|Riya support / gap|
|---|---|---|---|---|---|---|
|Thoughts/Promises|Y|Y|Y|Y|Wall|None; retrievalgap|
|Tasks|Y|Y|Y|Y|Filters|Todayread/create/limitedreschedule; no generaledit/delete|
|Reminders|Y|Y|Y|Y|Lists|Upcomingread/indirectcreation; no standaloneedit/missingtimecontext|
|Focus/timers|Y|Y|Pause/resume|Abandon|History|No start/controltool|
|Expenses/budgets/goals|Y|Y|Y|Y|Periods/category|Expensecreate/todayspendinsight; weeklyquery/edit/delete gap|
|Nested learning|Y|Y|Y|Y|Course/module|Activecourseinsight/lecturecomplete; persistenceverificationgap|
|Challenges|Y|Y|Amend/archive|Y|Chooser|None|
|Water|Y|Y|Goal|Logdelete|History|Log; outcomeverificationgap|
|Medicine|Y|Y|Limited|Y|Lists|Today/statusread|
|Walk|Y|Y|Controls/notes|Y|History|Distanceinsight; no GPS action|
|Pipeline|Y|Y|Y|Y|Y|Plannercontext; noCRUDtools|
|Interview|Y|Y|Y|Y|Y|No preparationchoiceworkflow|
|DSA|Y|Y|Limited|Y|Filters|Weeklycountinsight/fixedconcepts|
|Consistency|Y|Log|Y|Cleanup|Calendar|Differentproviderstreakinsight|
|Resume/files|Y|Y|Notes|Y|Versions|None; sharingneedsconsent|
|Analytics/series/phases|Y|Y|Y|Y|Drilldown|Mixedplanner/insight; dailydata mislabeledweekly|
|Reader|Y|Picker|Capture|Externalfile|Built-in|None|
|Settings/backup|Y|Export|Y|Reset|No|None; consequentialactionsrequireconfirm|
|Chai/audio|Y|Session|Controls|Finish|Presets|None|
|Help/navigation|Y|n/a|n/a|n/a|No unifiedsearch|Generichelp/cardlinks; no maintainedregistry|

### Proposed registry contract (architectural review, not claimed implementation)

Retain Riverpod/Drift. Typed interpretation→context→validation→permission→confirmation→handler→verifiedresult→UI/report. Persist requestID/approvedpayload/state/resultIDs for retries/restart; migrate/export compatibly. Singlelocalprofile only; no multi-userguarantee. Retrieved content remains inertdata, never parserinput. Sanitizeerrors without personaltext. Unsupportedaction→clearanswer+realroute. Financial/bulk/destructive/file-sharing confirm; reads don't. Separate saved reminder from OS permission/scheduling. Active timer conflict guard.

|ID / description|Schema / required|Permission/class/confirm|Validation / actualhandler|Success / failure / route|
|---|---|---|---|---|
|tasks.today|date?:localdate|Localread/none|Calendar; TaskDao.watchTasksByDate|Rows/unavailable/today|
|tasks.create|title!,date?,minutes?|Localwrite/review|1–300title/validdate/positive;insert+getTaskById|SavedID/not-saved/today|
|tasks.reschedule|ids!:int[],at!:ISO|Localwrite/confirm|Everytargetexists;transactionupdate|Changedrows/rollback/today|
|reminders.list|{}|Localread/none|ReminderDao.watchUpcomingReminders|Rows/unavailable/reminders|
|reminders.create|title!,at!,taskId?|Localwrite/review; OSpermissionseparate|Futuredate/linkexists;insert+reread+scheduleoutcome|Saved+alertstatus/error/reminders|
|reminders.edit|id!,at!|Localwrite/review|ResolvechosenID/futuredate;update+cancelschedule|Verifiedrow/error/reminders|
|thoughts.search|query!,archived?:bool|Localread/none|Boundquery/length/limit;DAOadapter|Matchingrecords/unavailable/thought-wall|
|expenses.create|amount!:number,title!,category?,account?|Financialwrite/confirm|Finitepositive/title;insert+reread|Savedamount/no-save/money|
|expenses.summary|from!,to!|Financialread/none|Localbounds/expensetype;querysum|Actualperiodtotal/unavailable/money|
|focus.start|minutes!:int,taskId?|Localwrite/explicitconsent|Duration/activeconflict;existingnotifier|Activeverified/conflict/focus|
|learning.complete|courseId!,lectureIds!|Localwrite/review|Belongtocourse;awaitpersist/reread|Exactcompleted/error/learning|
|hydration.log|ml!:int|Localwrite/review|Positivebounded;addWater+reread|Savedamount/error/hydration|
|medicine.today|{}|Sensitive localread/explicitrequest|MedicineService actualstatus|Doses/unavailable/medicine|
|help.feature|feature!:enum|Read/none|Registry/guide lookup|Actualguide/unsupported/featureroute|
|navigation.open|route!:allowlist|Navigate/none|Allowlist/identitypolicy;routerpush|Destination/routeerror/chosenroute|
|records.delete|type!:enum,id!:int|Destructivewrite/confirm|Ownership/existence/cascade;existingservice|Verifieddeletion/error/feature|

NLP: missing reminder time asks when; ambiguous reminder edit asks which; interviewpreparation offers task/reminder/timer/checklist choice before writes. Nine examplecommands map to the registry but **are not all implemented**. No decorative timer/checklist chips before real handlers.

## F. Prioritized roadmap / acceptance

|Priority/phase|Problem→solution/benefit|Components, complexity, dependencies, risk|Acceptance|
|---|---|---|---|
|P0/1|Riyafalsesuccess→confirmation/resultbasedreporting→trust|AI screen/service,medium,existingDAOs,multiwrite/historyrisk|Failure nevergreen; writesapproved; repeatedtapno duplicate|
|P0/1|Newuser/staledaystreak→calendarcontinuity/rollover→accurateprogress|streak/Home,medium,prefsdates,historyrescuecompatibility|Freshnorisk/day1/active/broken/recovered/midnight|
|P0/5 approval|No durable registry→typedactions/executionledger→safe retries|AI/DAO/schema,high,migration/backup,riskarchitecturalscope|Idempotent restart/retry, faulttests|
|P0 futureapproval|Hardcodedauth→deviceprivacyor realaccounts→honestsecurity|auth/router/storage,highifaccounts,identitychoice,migrationrisk|Clearaccessmodel, isolationifaccounts|
|P1/1–3|DuplicateCTAs/inputs→singleprimary+48dp→cleareractions|Money/Wall/AI/Home,low,currentwidgets,lowrisk|Duplicateassertions/semantics/themes/textscale|
|P1/1 approval|Theme referenceunclear→historiccomparison→preserveidentity|tokens/atmosphere,medium,screenshotchoice,visualrisk|Reviewedchosenreference/no-bluepreference|
|P1/4–5 approval|Languagegaps→search/period/reminder/timer/help tools→lessnavigation|Registry/parser/handlers,high,confirmedexecution,moderate|Requestedexamples truthful/minimalclarification|
|P1/2 approval|Careerentrygate→optionalcompanies→dailytoolaccess|Onboarding/profile/Splash,medium,routinglifecycle,moderate|Noncareer reachesHome/backwardprofilecompatible|
|P1/7|Ambiguousalerts→savedvsOSresult/retry→trust|Notifications/services,medium,OSperms,moderate|Denied/fallback reported; physicaldeliverytested|
|P2/2|Longguides/rawthoughts→shortsteps/quoteonce→readability|Guide/sharedpresentation,low,existinghelp,low|Once/replay/contentpreserved/quote tests|
|P2/2–7|Motion/contrast/fonts→reducedmotion/offlinefonts→accessibility|Painters/tokens/fonts,medium,fontlicense,moderate|Reducedmotionstatic/contrastmeasured/offlineparity|
|P2/3–4|Lostdraft/retyping→persistdraft/source links→continuation|Home/prefs/provenance,medium,migrationoptional,bloatrisk|Draftrestart/noautomaticcreation|
|P3 approval|Fragmentedretrieval→universal localsearch→findhistory|DAO/prefs/adapters,high,ownership/archivepolicy,privacymaintenance|Localboundedresults/sourcechips/performance|
|P3 approval|Manymodules→userpinnedactions/contextresume→relevance|Home/settings,medium,opt-in,bloatrisk|Onehelpfulaction/no mandatorynewpanels|

Part13 approval boundary: significant palette/layout replacement, modular registry expansion/durableledger, onboarding restructuring, provenance migration and universal search require review. Low-risk correctness/copy/duplicate removal/input alignment/quotepresentation proceed with tests. No resets/remoteAI/dependency replacement planned.

## Friction / metrics / QA

Source estimates (not timings): Home thought tapline+send2taps/1screen; expense Money→add→save plus typing/1sheet; thought→Todo menu+convert2; directedit1+save; reminder add/title/date/time/save varies pickerchoices; Focus open/pick/start2–3afterentry. Preserve confirmation/Undo rather than optimizing rawtapcount. Futuremeasures: medianentrytime, reminder saved→OSscheduled rate, verifiedAI actions/attempts and failures, duplicatewrites, searchopenrate, layout errors, p95load. No inventedbaseline.

Planned QA: fullsuite inventory, targeted model/widget/DBerror/repeatedtap tests, analysis/diffcheck/releasebuild, deviceinstall onlywhenconnected. Cover navigation/CRUD/persistence/theme/streak/date/timezone/empty/error/loading/longcontent/keyboard/textscale/restart/simultaneousupdates. OSalerts/GPS/backgroundbattery/screenreader/actualfonts/networkfailure/performance remain unverified until executed. An APK build does not verify these.
