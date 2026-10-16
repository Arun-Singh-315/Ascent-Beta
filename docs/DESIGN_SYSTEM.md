# Ascent design system

Current contributor guide · reviewed 12 October 2026. The definitions in `lib/app/theme/` and active component APIs are authoritative; this guide does not promise that every historical screen already follows every convention.

## Themes and surfaces

Resolve colors through `context.glass` and semantic color extensions. Use readable content surfaces over restrained atmospheric backgrounds. Keep glass effects bounded; avoid a blur or continuous animation for every row. Verify both light and dark modes rather than copying a dark-mode literal.

Use `AscentScaffold` for ordinary feature pages where its framing fits, `AscentCard` for grouped surfaces and `GlassSurface` for appropriate floating glass treatments. Full-screen entry and specialized reading/player surfaces have their own layouts. `AscentCard` supports glass, solid, elevated and outlined variants.

## Typography and dimensions

Use `AscentTextStyles` and `AscentDimensions`/`AscentRadii` rather than inventing scales at each call site. Shared typography includes Plus Jakarta Sans, Inter and JetBrains Mono; Home also uses Bricolage Grotesque and DM Sans. Reader typography has separate reading choices. Keep bundled font files, manifests and licenses together.

Standard spacing tokens range from 4 px to 32 px. Consult `dimension_tokens.dart` for actual component dimensions and radii. Controls must remain usable with large text, long labels, screen readers and the keyboard; do not force their content into a fixed height that clips.

## Controls and feedback

- Reuse `AscentButton` variants and appropriate tactile feedback.
- `AscentDialog.confirm` returns the user's choice; `AscentDialog.alert` presents information. Check the actual named-argument API before calling.
- `AscentSnackBar` and `showUndoSnackbar` provide common feedback patterns. Show success only after the relevant operation succeeds.
- Use `MessageComposer` for shared chat input. Other forms use feature-specific Material text fields with semantic theme colors.
- Feature sheets use `showModalBottomSheet`, with safe areas, keyboard insets, sensible height limits, scrolling and shared surface/radius tokens. There is no active generic `AscentBottomSheet` wrapper.
- Give destructive/bulk actions a clear scope and recovery where supported. Avoid duplicate submission while a write is pending.

## Home and navigation

Keep Home previews bounded with explicit full-view destinations. Preserve access to capture, tools, Riya and running sessions. Back/navigation behavior belongs to the router and main scaffold. Hiding a presentation section must never disable its background service.

Use concise labels, visible truncation affordances, accessible touch targets and reduced-motion alternatives. Keep implementation details out of everyday user flows unless they explain a meaningful state or choice.

The [component catalog](COMPONENT_CATALOG.md) lists current shared widgets. The [Mind Space plan](MIND_SPACE_FEEDBACK_PLAN.md) and [next update plan](NEXT_UPDATE_PLAN.md) describe proposed experiences separately from today's components.
