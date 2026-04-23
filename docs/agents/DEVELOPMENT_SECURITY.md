# Development & Security Standards

## Security Protocols
- **Screenshot Protection:** `SecurityService().protectScreen()` MUST be called in `main.dart` to prevent screenshots and screen recordings on supported platforms (Android).
- **Environment Integrity:** The application MUST perform device integrity checks (root/jailbreak detection) via `SecurityService` during initialization. If a security violation is detected, sensitive features should be disabled.
- **Data Security:** Sensitive data (JWT tokens, user IDs, private keys) MUST NOT be stored in plain text (SharedPreferences). Use `FlutterSecureStorage` via `PocketBaseService` ensure encryption at rest.
- **Reverse Engineering Prevention:** All production builds MUST use Flutter's obfuscation flags: `flutter build apk --obfuscate --split-debug-info=./debug-info`. This renames classes and methods to unreadable strings.
- **Admin Route Security:** The AdminService historically possessed a fallback hook authorizing the owner by email address. This is now STRICTLY RESTRICTED. `AdminService().isAdmin()` must only evaluate `user.data['role'] == '0'`. Furthermore, ALL screens and routes belonging to the administrator panel MUST wrap their `build` context with `if (!AdminService().isAdmin()) return AccessDeniedWidget();` to ensure no data is fetched or UI rendered if a standard user illegitimately forces navigation into the module.

## Database & Data Standards
- **Database Integrity:** You MUST always keep `pb_schema.json` updated with any changes made to the database logic. **CRITICAL:** Every time you add a new field or modify the database logic, you MUST immediately update `pb_schema.json` to reflect these changes.
- **Hardened Database Rules:** `pb_schema.json` MUST enforce `@request.auth.id != ""` for all list/view operations and strict owner-based update/delete rules for all collections.
- **API Audit Headers:** Every API request MUST include device metadata (ID, Model, OS) via `PocketBaseService` headers to allow server-side auditing and anomaly detection.

## Development Standards
- **Sync Priority:** In audio recording features, use aggressive FFmpeg flags (low buffer, fast probe) to ensure start/stop synchronization matches user interaction as closely as possible.
- **Feature Isolation:** When a new independent feature is to be implemented, it MUST be created in its own directory (e.g., `lib/features/new_feature/`) to maintain a modular and maintainable codebase.
- **OAuth Custom Tab Fallback (Android):** `window.close()` and `closeInAppWebView()` are fundamentally blocked by Android 13/14+ security policies inside Custom Tabs.
    - Path: `AndroidManifest.xml` MUST contain the `<data android:scheme="blindsocial" android:host="auth" />` intent.
    - Recovery: The HTML served by our internal loopback server must use `window.location.replace("blindsocial://auth");` to force the Android OS to bring our app to the foreground.
- **Changelog Updates:** `lib/features/profile/presentation/screens/changelog_screen.dart` MUST be updated with every new feature or version update, clearly listing the added/removed features for the user. Every update MUST also increment the version number in a sequential manner (e.g., 1.2.0 -> 1.2.1).
