# Project Guidelines

## UI & Layout Rules
- **SafeArea First:** Every page (Screen) and global component MUST be wrapped in a `SafeArea` widget to prevent content from being obscured by system bars (status bar, navigation bar, notches).
- **Overflow Prevention:** All layouts containing lists or dynamic content MUST use scrollable views (`ListView`, `SingleChildScrollView`) to prevent `RenderFlex` overflow errors on different screen sizes.
- **Bottom Sheets:** All modal bottom sheets MUST use `useSafeArea: true` and handle internal padding for the navigation bar area (using `MediaQuery.of(context).padding.bottom`) to ensure buttons are fully visible.

## Development Standards
- **Sync Priority:** In audio recording features, use aggressive FFmpeg flags (low buffer, fast probe) to ensure start/stop synchronization matches user interaction as closely as possible.
- **Database Integrity:** You MUST always keep `pb_schema.json` updated with any changes made to the database logic. Before performing any database-related operations, you MUST read `pb_schema.json` once to ensure full consistency and prevent memory drift regarding the schema structure.
