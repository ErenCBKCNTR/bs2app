# Bağımlılık Envanteri ve Sürüm Takibi

Bu dosya, projede kullanılan tüm harici paketlerin güncel sürümlerini ve çakışma risklerini takip etmek için kullanılır. Yeni bir paket eklenmeden önce mutlaka buradaki sürümlerle uyumluluk kontrol edilmelidir.

## Mevcut Paketler ve Sürümleri

| Kategori | Paket Adı | Mevcut Sürüm | Açıklama |
| :--- | :--- | :--- | :--- |
| **State Management** | `flutter_riverpod` | `^2.6.1` | Uygulama genelinde durum yönetimi. |
| **Backend** | `pocketbase` | `^0.20.0` | Veritabanı ve Auth işlemleri. |
| **Communication** | `livekit_client` | `^2.7.0` | Sesli ve görüntülü iletişim (VoIP). |
| **Firebase** | `firebase_core` | `^3.1.0` | Firebase temel yapılandırması. |
| **Firebase** | `firebase_messaging` | `^15.0.0` | Anlık bildirimler (Push Notifications). |
| **Notification** | `flutter_local_notifications` | `^18.0.0` | Yerel bildirim yönetimi. |
| **Audio** | `record` | `^6.2.0` | Ses kaydı yapma. |
| **Audio** | `audioplayers` | `^6.1.1` | Ses dosyalarını oynatma. |
| **Audio** | `just_audio` | `^0.9.42` | Gelişmiş ses oynatıcı (Radyo vb. için). |
| **Audio Utils** | `ffmpeg_kit_flutter_new_https` | `^2.0.0` | Ses/Video işleme ve dönüştürme. |
| **Security** | `flutter_secure_storage` | `^9.2.2` | Hassas verileri şifreli saklama. |
| **Security** | `safe_device` | `^1.1.7` | Root/Jailbreak tespiti. |
| **System** | `device_info_plus` | `^12.4.0` | Cihaz meta verilerine erişim. |
| **Storage** | `shared_preferences` | `^2.5.1` | Basit ayarların kalıcı saklanması. |
| **Permissions** | `permission_handler` | `^11.3.1` | Cihaz izinlerini yönetme. |
| **Database** | `sqflite` | `^2.3.3+3` | Yerel SQL veritabanı. |

## Bağımlılık Güncelleme ve Ekleme Kuralları
1.  **Her Zaman Web Araması Yap:** Bir paket eklemeden veya güncellemeden önce `google_search` aracını kullanarak mutlaka en güncel sürümünü ve `pub.dev` üzerindeki güncel dökümantasyonunu kontrol et.
2.  **Statik Bilgiye Güvenme:** AI eğitim verilerindeki veya dökümantasyonlardaki sürüm numaralarına asla güvenme, her zaman canlı web aramasıyla doğrula.
3.  **Çakışma Kontrolü:** Yeni bir paket eklenirken `flutter_riverpod` ve `pocketbase` gibi ana sürümlerle çakışıp çakışmadığını (örneğin `collection` veya `path` paketi bağımlılıkları üzerinden) kontrol et.
4.  **Envanter Güncelleme:** `pubspec.yaml` üzerinde yapılan her değişiklikten sonra bu dosyayı (`BAGIMLILIK_ENVANTERI.md`) mutlaka güncelle.
