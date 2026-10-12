# Ascent component catalog

Active source reference · reviewed 12 October 2026. Paths are relative to `lib/`.

| Component | Source | Purpose |
| --- | --- | --- |
| AscentScaffold | `shared/widgets/ascent_scaffold.dart` | Shared page framing and back controls |
| MainScaffold | `shared/widgets/main_scaffold.dart` | Shell navigation, back behavior and shared session surfaces |
| AscentCard | `shared/widgets/ascent_card.dart` | Glass, solid, elevated and outlined surfaces |
| GlassSurface | `shared/widgets/glass_surface.dart` | Theme-aware glass treatment |
| AscentButton | `shared/widgets/ascent_button.dart` | Shared action variants |
| AscentDialog | `shared/widgets/ascent_dialog.dart` | Confirm and alert helpers |
| AscentSnackBar / showUndoSnackbar | `shared/widgets/ascent_snack_bar.dart`, `undo_snackbar.dart` | Feedback and reversible actions |
| MessageComposer | `shared/widgets/message_composer.dart` | Chat-style text entry |
| ChatBubbleCard | `shared/widgets/chat_bubble_card.dart` | Chat surfaces and optional tail treatment |
| LiveSessionBar | `shared/widgets/live_session_bar.dart` | Active/paused session entry and controls |
| EmptyState / SkeletonShimmer | `shared/widgets/empty_state.dart`, `skeleton_shimmer.dart` | Empty and loading states |
| AscentLogo / AscentAtmosphereBackground | `shared/widgets/ascent_logo.dart`, `ascent_atmosphere.dart` | Brand and shared atmosphere |
| AscentDrawer | `shared/widgets/ascent_drawer.dart` | Tool navigation |
| AnimatedWaterCard | `shared/widgets/animated_water_card.dart` | Hydration presentation |
| FeatureGuideHost and guide helpers | `shared/widgets/feature_guide.dart` | First-use help and replayable guidance |
| Thought presentation | `shared/widgets/thought_presentation.dart` | Display-only quotation formatting |
| Home components | `features/home/widgets/` | Header, activities, learning, reminders, thought capture and tool previews |

Feature-specific sheets and forms use Material controls with shared theme tokens. Unused prototype wrappers and replaced Home/break widgets were removed; do not import classes from historical audits. See current call sites when extending a flow.
