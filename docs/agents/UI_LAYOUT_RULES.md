# UI & Layout Rules

## Core Principles
- **SafeArea First:** Every page (Screen) and global component MUST be wrapped in a `SafeArea` widget to prevent content from being obscured by system bars (status bar, navigation bar, notches).
- **Overflow Prevention:** All layouts containing lists or dynamic content MUST use scrollable views (`ListView`, `SingleChildScrollView`) to prevent `RenderFlex` overflow errors on different screen sizes.
- **Bottom Sheets:** All modal bottom sheets MUST use `useSafeArea: true` and handle internal padding for the navigation bar area (using `MediaQuery.of(context).padding.bottom`) to ensure buttons are fully visible.
- **Minimalist & Symmetric Design:** All UI components (especially in group voice chat rooms, modal dialogs, or control panels) MUST maintain a strict symmetrical layout structure. Symmetrical button placement, balanced padding, and perfectly aligned controls are non-negotiable.
- **Identity Display Priority:** Always prioritize displaying 'usernames' over real 'full names' or prominent profile pictures across all UI elements. The interface must strictly adhere to a functional, uncluttered, and minimalist design language.

## Accessibility (Screen Readers)
- Every interactive element (`IconButton`, `InkWell`, `ElevatedButton`, etc.) MUST have a meaningful `semanticsLabel` or `tooltip` to avoid being read as "unlabeled".
- **No Double Labeling:** Ensure interactive elements do not have redundant or multiple semantic nodes. If wrapping a button in a `Semantics` widget, use `ExcludeSemantics` on the button's internal components (like Icons) or use the button's own semantic properties (e.g., `tooltip`) to avoid "unlabeled" (etiketsiz) announcements after the primary label.
- Redundant descriptions (e.g., "buton butonu") MUST be avoided.
- Large text and custom widgets should use `Semantics` widget headers where appropriate for better navigation.
- Images MUST have `semanticsLabel` providing a description of the image content.
