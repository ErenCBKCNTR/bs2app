# Project Guidelines

> [!IMPORTANT]
> **MANDATORY TASK START CHECK:** You MUST read this file at the beginning of EVERY task. This is non-negotiable. This file is the source of truth for existing components, services, and architectural standards. Before creating anything new, check if a suitable component or service already exists here.
> **SECURITY CHECK:** Before performing any database-related operations, you MUST read `pb_schema.json` once to ensure full consistency and prevent memory drift regarding the schema structure.

## UI & Layout Rules
- **SafeArea First:** Every page (Screen) and global component MUST be wrapped in a `SafeArea` widget to prevent content from being obscured by system bars (status bar, navigation bar, notches).
- **Overflow Prevention:** All layouts containing lists or dynamic content MUST use scrollable views (`ListView`, `SingleChildScrollView`) to prevent `RenderFlex` overflow errors on different screen sizes.
- **Bottom Sheets:** All modal bottom sheets MUST use `useSafeArea: true` and handle internal padding for the navigation bar area (using `MediaQuery.of(context).padding.bottom`) to ensure buttons are fully visible.
- **Accessibility (Screen Readers):** 
    - Every interactive element (`IconButton`, `InkWell`, `ElevatedButton`, etc.) MUST have a meaningful `semanticsLabel` or `tooltip` to avoid being read as "unlabeled".
    - **No Double Labeling:** Ensure interactive elements do not have redundant or multiple semantic nodes. If wrapping a button in a `Semantics` widget, use `ExcludeSemantics` on the button's internal components (like Icons) or use the button's own semantic properties (e.g., `tooltip`) to avoid "unlabeled" (etiketsiz) announcements after the primary label.
    - Redundant descriptions (e.g., "buton butonu") MUST be avoided.
    - Large text and custom widgets should use `Semantics` widget headers where appropriate for better navigation.
    - Images MUST have `semanticsLabel` providing a description of the image content.

## Development Standards
- **Sync Priority:** In audio recording features, use aggressive FFmpeg flags (low buffer, fast probe) to ensure start/stop synchronization matches user interaction as closely as possible.
- **Database Integrity:** You MUST always keep `pb_schema.json` updated with any changes made to the database logic. **CRITICAL:** Every time you add a new field or modify the database logic, you MUST immediately update `pb_schema.json` to reflect these changes. Before performing any database-related operations, you MUST read `pb_schema.json` once to ensure full consistency and prevent memory drift regarding the schema structure.
- **Feature Isolation:** When a new independent feature is to be implemented, it MUST be created in its own directory (e.g., `lib/features/new_feature/`) to maintain a modular and maintainable codebase.
- **OAuth Custom Tab Fallback (Android):** `window.close()` and `closeInAppWebView()` are fundamentally blocked by Android 13/14+ security policies inside Custom Tabs. To properly close the OAuth custom web view after a successful login (e.g., Google OAuth loopback), we utilize **Deep Linking (Intent Redirect)**. 
    - The `AndroidManifest.xml` MUST contain the `<data android:scheme="blindsocial" android:host="auth" />` intent.
    - The HTML served by our internal loopback server must use `window.location.replace("blindsocial://auth");` to force the Android OS to bring our app to the foreground, which natively kills the blocking Custom Tab. Never rely solely on timer-based `close()` calls for Android.
- **Admin Route Security:** The AdminService historically possessed a fallback hook authorizing the owner by email address. This is now STRICTLY RESTRICTED. `AdminService().isAdmin()` must only evaluate `user.data['role'] == '0'`. Furthermore, ALL screens and routes belonging to the administrator panel MUST wrap their `build` context with `if (!AdminService().isAdmin()) return AccessDeniedWidget();` to ensure no data is fetched or UI rendered if a standard user illegitimately forces navigation into the module.
- **Reverse Engineering Prevention:** All production builds MUST use Flutter's obfuscation flags: `flutter build apk --obfuscate --split-debug-info=./debug-info`. This renames classes and methods to unreadable strings.
- **Data Security:** Sensitive data (JWT tokens, user IDs, private keys) MUST NOT be stored in plain text (SharedPreferences). Use `FlutterSecureStorage` via `PocketBaseService` ensure encryption at rest.
- **Environment Integrity:** The application MUST perform device integrity checks (root/jailbreak detection) via `SecurityService` during initialization. If a security violation is detected, sensitive features should be disabled.
- **Screenshot Protection:** `SecurityService().protectScreen()` MUST be called in `main.dart` to prevent screenshots and screen recordings on supported platforms (Android).
- **API Audit Headers:** Every API request MUST include device metadata (ID, Model, OS) via `PocketBaseService` headers to allow server-side auditing and anomaly detection.
- **Hardened Database Rules:** `pb_schema.json` MUST enforce `@request.auth.id != ""` for all list/view operations and strict owner-based update/delete rules for all collections.

---

## System Component & Service Catalog

### 🏗️ Core UI Components (`lib/core/widgets/`)
These are reusable widgets that MUST be used across the app to ensure consistency.

| Component | Directory | Description |
| :--- | :--- | :--- |
| `ChatInputField` | `lib/core/widgets/chat_input_field.dart` | The standard input field for all chats (Private/Server). Handles text sending, audio recording (with timer), and reply UI. |
| `VoiceMessageWidget` | `lib/core/widgets/voice_message_widget.dart` | Standard player for voice messages. Handles play/pause, seek (5s), and progress tracking with screen reader support. |
| `ExpandableText` | `lib/core/widgets/expandable_text.dart` | Handles long text content with "read more/less" functionality for better layout management. |

### ⚙️ Core Services (`lib/core/services/`)
Primary singleton services for backend and system-level operations.

| Service | Directory | Description |
| :--- | :--- | :--- |
| `PocketBaseService` | `lib/core/services/pocketbase_service.dart` | Main database client configuration and auth state management. |
| `SettingsService` | `lib/core/services/settings_service.dart` | Manages user preferences (vibration, sound, text settings), persists locally. |
| `NotificationService` | `lib/core/services/notification_service.dart` | Handles push notifications and local alert management. |

### 🛠️ Utilities (`lib/core/utils/`)
| Util | Directory | Description |
| :--- | :--- | :--- |
| `AppLogger` | `lib/core/utils/logger.dart` | Centralized logging system (Info, Warning, Error). |
| `ProfanityFilter` | `lib/core/utils/profanity_filter.dart` | Filters contents against blacklisted words before rendering in UI. |

### 🚀 Feature Modules (`lib/features/`)
| Module | Directory | Description |
| :--- | :--- | :--- |
| `Auth` | `lib/features/auth/` | Login, Register, and Account Recovery flows. |
| `Chat` | `lib/features/chat/` | Private messaging (1:1), active chats list, and call (VoIP) features. |
| `Servers` | `lib/features/servers/` | Community server management, room lists, and room chat interfaces. |
| `Profile` | `lib/features/profile/` | User settings, profile viewing, and social connections. |
| `Radio` | `lib/features/radio/` | Live radio streaming and recording features. |
| `Admin` | `lib/features/admin/` | Management tools for moderators and system admins. |
| `Developer` | `lib/features/developer/` | Debugging tools and logs for development use. |
