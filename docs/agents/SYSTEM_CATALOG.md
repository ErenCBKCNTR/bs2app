# System Component & Service Catalog

## 🏗️ Core UI Components (`lib/core/widgets/`)
Reusable widgets used across the app to ensure consistency.

| Component | Directory | Description |
| :--- | :--- | :--- |
| `ChatInputField` | `lib/core/widgets/chat_input_field.dart` | The standard input field for all chats (Private/Server). Handles text sending, audio recording (with timer), and reply UI. |
| `VoiceMessageWidget` | `lib/core/widgets/voice_message_widget.dart` | Standard player for voice messages. Handles play/pause, seek (5s), and progress tracking with screen reader support. |
| `ExpandableText` | `lib/core/widgets/expandable_text.dart` | Handles long text content with "read more/less" functionality for better layout management. |

## ⚙️ Core Services (`lib/core/services/`)
Primary singleton services for backend and system-level operations.

| Service | Directory | Description |
| :--- | :--- | :--- |
| `PocketBaseService` | `lib/core/services/pocketbase_service.dart` | Main database client configuration and auth state management. |
| `SettingsService` | `lib/core/services/settings_service.dart` | Manages user preferences (vibration, sound, text settings), persists locally. |
| `NotificationService` | `lib/core/services/notification_service.dart` | Handles push notifications and local alert management. |
| `SecurityService` | `lib/core/services/security_service.dart` | Handles device integrity and screen protection logic. |

## 🛠️ Utilities (`lib/core/utils/`)
| Util | Directory | Description |
| :--- | :--- | :--- |
| `AppLogger` | `lib/core/utils/logger.dart` | Centralized logging system (Info, Warning, Error). |
| `ProfanityFilter` | `lib/core/utils/profanity_filter.dart` | Filters contents against blacklisted words before rendering in UI. |

## 🚀 Feature Modules (`lib/features/`)
| Module | Directory | Description |
| :--- | :--- | :--- |
| `Auth` | `lib/features/auth/` | Login, Register, and Account Recovery flows. |
| `Chat` | `lib/features/chat/` | Private messaging (1:1), active chats list, and call (VoIP) features. |
| `Servers` | `lib/features/servers/` | Community server management, room lists, and room chat interfaces. |
| `Profile` | `lib/features/profile/` | User settings, profile viewing, and social connections. |
| `Radio` | `lib/features/radio/` | Live radio streaming and recording features. |
| `Admin` | `lib/features/admin/` | Management tools for moderators and system admins. |
| `Developer` | `lib/features/developer/` | Debugging tools and logs for development use. |
