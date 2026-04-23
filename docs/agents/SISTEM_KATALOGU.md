# Sistem Bileşenleri ve Servis Kataloğu

## 🏗️ Temel UI Bileşenleri (`lib/core/widgets/`)
Tutarlılığı sağlamak için uygulama genelinde kullanılan yeniden kullanılabilir widget'lar.

| Bileşen | Dizin | Açıklama |
| :--- | :--- | :--- |
| `ChatInputField` | `lib/core/widgets/chat_input_field.dart` | Tüm sohbetler (Özel/Sunucu) için standart giriş alanı. Metin gönderimi, ses kaydı (zamanlayıcılı) ve yanıt UI'ını yönetir. |
| `VoiceMessageWidget` | `lib/core/widgets/voice_message_widget.dart` | Sesli mesajlar için standart oynatıcı. Oynat/duraklat, sarma (5sn) ve ekran okuyucu desteği ile ilerleme takibini yönetir. |
| `ExpandableText` | `lib/core/widgets/expandable_text.dart` | Daha iyi yerleşim yönetimi için "daha fazla/az oku" işlevselliğine sahip uzun metin içeriklerini yönetir. |

## ⚙️ Temel Servisler (`lib/core/services/`)
Arka uç ve sistem düzeyindeki işlemler için birincil singleton servisler.

| Servis | Dizin | Açıklama |
| :--- | :--- | :--- |
| `PocketBaseService` | `lib/core/services/pocketbase_service.dart` | Ana veritabanı istemci yapılandırması ve yetkilendirme durumu yönetimi. |
| `SettingsService` | `lib/core/services/settings_service.dart` | Kullanıcı tercihlerini (titreşim, ses, metin ayarları) yönetir, yerel olarak saklar. |
| `NotificationService` | `lib/core/services/notification_service.dart` | Anlık bildirimleri ve yerel uyarı yönetimini yönetir. |
| `SecurityService` | `lib/core/services/security_service.dart` | Cihaz bütünlüğü ve ekran koruma mantığını yönetir. |

## 🛠️ Yardımcı Araçlar (Utilities) (`lib/core/utils/`)
| Araç | Dizin | Açıklama |
| :--- | :--- | :--- |
| `AppLogger` | `lib/core/utils/logger.dart` | Merkezi günlük kaydı sistemi (Bilgi, Uyarı, Hata). |
| `ProfanityFilter` | `lib/core/utils/profanity_filter.dart` | İçerikleri kullanıcı arayüzünde oluşturmadan önce kara listedeki kelimelere karşı filtreler. |

## 🚀 Özellik Modülleri (`lib/features/`)
| Modül | Dizin | Açıklama |
| :--- | :--- | :--- |
| `Auth` | `lib/features/auth/` | Giriş, Kayıt ve Hesap Kurtarma akışları. |
| `Chat` | `lib/features/chat/` | Özel mesajlaşma (1:1), aktif sohbet listesi ve arama (VoIP) özellikleri. |
| `Servers` | `lib/features/servers/` | Topluluk sunucusu yönetimi, oda listeleri ve oda sohbet arayüzleri. |
| `Profile` | `lib/features/profile/` | Kullanıcı ayarları, profil görüntüleme ve sosyal bağlantılar. |
| `Radio` | `lib/features/radio/` | Canlı radyo yayını ve kayıt özellikleri. |
| `Admin` | `lib/features/admin/` | Moderatörler ve sistem yöneticileri için yönetim araçları. |
| `Developer` | `lib/features/developer/` | Geliştirme kullanımı için hata ayıklama araçları ve günlükler. |
