# Project Guidelines

## UI & Layout Rules
- **SafeArea First:** Every page (Screen) and global component MUST be wrapped in a `SafeArea` widget to prevent content from being obscured by system bars (status bar, navigation bar, notches).
- **Overflow Prevention:** All layouts containing lists or dynamic content MUST use scrollable views (`ListView`, `SingleChildScrollView`) to prevent `RenderFlex` overflow errors on different screen sizes.
- **Bottom Sheets:** All modal bottom sheets MUST use `useSafeArea: true` and handle internal padding for the navigation bar area (using `MediaQuery.of(context).padding.bottom`) to ensure buttons are fully visible.
- **Accessibility (Screen Readers):** 
    - Every interactive element (`IconButton`, `InkWell`, `ElevatedButton`, etc.) MUST have a meaningful `semanticsLabel` or `tooltip` to avoid being read as "unlabeled".
    - Redundant descriptions (e.g., "buton butonu") MUST be avoided.
    - Large text and custom widgets should use `Semantics` widget headers where appropriate for better navigation.
    - Images MUST have `semanticsLabel` providing a description of the image content.

## Development Standards
- **Sync Priority:** In audio recording features, use aggressive FFmpeg flags (low buffer, fast probe) to ensure start/stop synchronization matches user interaction as closely as possible.
- **Database Integrity:** You MUST always keep `pb_schema.json` updated with any changes made to the database logic. **CRITICAL:** Every time you add a new field or modify the database logic, you MUST immediately update `pb_schema.json` to reflect these changes. Before performing any database-related operations, you MUST read `pb_schema.json` once to ensure full consistency and prevent memory drift regarding the schema structure.
- **Feature Isolation:** When a new independent feature is to be implemented, it MUST be created in its own directory (e.g., `lib/features/new_feature/`) to maintain a modular and maintainable codebase.
