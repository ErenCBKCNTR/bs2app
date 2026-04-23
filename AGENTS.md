# 📚 YZ AJAN FİHRİSTİ (AGENTS ENCYCLOPEDIA)

Bu dosya, projede kullanılan tüm Yapay Zeka Ajanı yönlendirmelerinin, iş akışlarının ve proje kurallarının merkezi (ansiklopedik) deposudur. Ajan, bu fihristteki kuralları okumadan ve bağlamı kurmadan eyleme geçmemelidir.

## 📑 İÇİNDEKİLER
1. [İletişim ve Temel Protokol](#1-iletisim-ve-temel-protokol)
2. [Geliştirme ve Güvenlik Standartları](#2-gelistirme-ve-guvenlik-standartlari)
3. [Arayüz ve Yerleşim Kuralları](#3-arayuz-ve-yerlesim-kurallari)
4. [Hata Çözüm ve Teknik Bilgi Rehberi](#4-hata-cozum-ve-teknik-bilgi-rehberi)
5. [Bağımlılık Envanteri ve Sürüm Takibi](#5-bagimlilik-envanteri-ve-surum-takibi)
6. [Sistem Bileşenleri ve Servis Kataloğu](#6-sistem-bilesenleri-ve-servis-katalogu)
7. [Proje Yol Haritası ve Yapılacaklar](#7-proje-yol-haritasi-ve-yapilacaklar)

---

<br>

<h2 id="1-iletisim-ve-temel-protokol">1. İLETİŞİM VE TEMEL PROTOKOL</h2>

### Kaynak Referansı Şeffaflığı
- **Okuma Doğrulaması:** Üretilen HER yanıt için, yapay zeka ajanı görev sırasında `AGENTS.md` içerisindeki hangi bölümlerin veya başlıkların referans alındığını açıkça belirtmelidir.
- **Raporlama Formatı:** Ajan, okunan bölümleri yanıtının başında net bir şekilde listelemelidir. (Örnek: `Okunan Bölümler: Arayüz ve Yerleşim Kuralları, Geliştirme Güvenliği`)
- **Doğrulama Amacı:** Bu, kullanıcının yapay zekanın belirlenen proje hafızasına ve modüler yönergelere uyduğundan emin olmasını sağlar.

### Dil ve Yerelleştirme Kuralı
- **Zorunlu Dil (Türkçe):** Bundan sonra oluşturulan tüm yeni kurallar, dökümanlar, hafıza dosyaları ve günlük kayıtları MUTLAKA Türkçe olarak yazılmalıdır. İngilizce dökümantasyon sadece teknik terimler için kullanılabilir.
- **Dosya İsimlendirme:** Yeni oluşturulan hafıza dosyalarının isimleri de Türkçe karakter içermeyen ancak Türkçe anlam taşıyan şekilde (örneğin: `YENI_KURAL.md`) seçilmelidir.

### Görev Başlatma
- **ZORUNLU GÖREV BAŞLATMA KONTROLÜ:** Yapay zeka ajanları, HER görevin başında bu ana `AGENTS.md` dosyasını okumalıdır. Bu kural tartışılamazdır.
- Yeni bir şey oluşturmadan önce, `Sistem Katalogu` bölümünde uygun bir bileşenin veya servisin zaten mevcut olup olmadığını kontrol edin.
- Yeni bir bağımlılık eklemeden önce `Bağımlılık Envanteri` bölümünü kontrol edin ve pub.dev üzerinden mutlaka web araması yapın.
- Veritabanıyla ilgili herhangi bir işlem yapmadan önce, tam tutarlılığı sağlamak için `pb_schema.json` dosyasını bir kez okuyun.

---

<br>

<h2 id="2-gelistirme-ve-guvenlik-standartlari">2. GELİŞTİRME VE GÜVENLİK STANDARTLARI</h2>

### Güvenlik Protokolleri
- **Ekran Koruması:** Desteklenen platformlarda (Android) ekran görüntüsü alınmasını ve ekran kaydı yapılmasını önlemek için `main.dart` içerisinde `SecurityService().protectScreen()` mutlaka çağrılmalıdır.
- **Çevre Bütünlüğü:** Uygulama, başlatma sırasında `SecurityService` aracılığıyla cihaz bütünlüğü kontrollerini (root/jailbreak tespiti) yapmalıdır. Bir güvenlik ihlali tespit edilirse hassas özellikler devre dışı bırakılmalıdır.
- **Veri Güvenliği:** Hassas veriler (JWT token'ları, kullanıcı ID'leri, özel anahtarlar) düz metin olarak (SharedPreferences) saklanmamalıdır. Verilerin şifrelenmiş olarak saklanmasını sağlamak için `PocketBaseService` üzerinden `FlutterSecureStorage` kullanın.
- **Tersine Mühendislik Önleme:** Tüm üretim sürümleri Flutter'ın gizleme (obfuscation) bayraklarını kullanmalıdır: `flutter build apk --obfuscate --split-debug-info=./debug-info`. Bu işlem, sınıfları ve metodları okunamaz diziler olarak yeniden adlandırır.
- **Admin Rotası Güvenliği:** AdminService geçmişte sahibini e-posta adresiyle yetkilendiren bir geri dönüş mekanizmasına sahipti. Bu artık KESİNLİKLE KISITLANMIŞTIR. `AdminService().isAdmin()` sadece `user.data['role'] == '0'` kontrolünü yapmalıdır. Ayrıca, yönetici paneline ait tüm ekranlar ve rotalar, standart bir kullanıcının modüle haksız yere girmesi durumunda hiçbir verinin çekilmemesini ve UI'ın oluşturulmamasını sağlamak için `build` bağlamlarını `if (!AdminService().isAdmin()) return AccessDeniedWidget();` ile sarmalamalıdır.

### Veritabanı ve Veri Standartları
- **Veritabanı Bütünlüğü:** Veritabanı mantığında yapılan her türlü değişiklikle birlikte `pb_schema.json` dosyasını her zaman güncel tutmalısınız. **KRİTİK:** Yeni bir alan eklediğinizde veya veritabanı mantığını değiştirdiğinizde, bu değişiklikleri yansıtmak için `pb_schema.json` dosyasını derhal güncellemelisiniz.
- **Sıkılaştırılmış Veritabanı Kuralları:** `pb_schema.json`, tüm listeleme/görüntüleme işlemleri için `@request.auth.id != ""` kuralını ve tüm koleksiyonlar için katı sahibi tabanlı güncelleme/silme kurallarını zorunlu kılmalıdır.
- **API Denetim Başlıkları:** Her API isteği, sunucu tarafında denetim ve anomali tespiti yapılabilmesi için `PocketBaseService` başlıkları aracılığıyla cihaz meta verilerini (ID, Model, OS) içermelidir.

### Geliştirme Standartları
- **Senkronizasyon Önceliği:** Ses kayıt özelliklerinde, başlatma/durdurma senkronizasyonunun kullanıcı etkileşimiyle mümkün olduğunca eşleşmesini sağlamak için agresif FFmpeg bayrakları (düşük tampon, hızlı probe) kullanın.
- **Özellik İzolasyonu:** Yeni bir bağımsız özellik uygulanacağında, modüler ve sürdürülebilir bir kod tabanı sağlamak için kendi dizininde (örneğin `lib/features/yeni_ozellik/`) oluşturulmalıdır.
- **OAuth Özel Sekme Geri Dönüşü (Android):** `window.close()` ve `closeInAppWebView()` fonksiyonları, Özel Sekmeler (Custom Tabs) içindeki Android 13/14+ güvenlik politikaları nedeniyle temelden engellenmiştir.
    - Yol: `AndroidManifest.xml`, `<data android:scheme="blindsocial" android:host="auth" />` intent'ini içermelidir.
    - Kurtarma: Dahili loopback sunucumuz tarafından sunulan HTML, Android işletim sistemini uygulamamızı ön plana çıkarmaya zorlamak için `window.location.replace("blindsocial://auth");` kullanmalıdır.
- **Değişiklik Günlüğü (Changelog) Güncellemeleri:** `lib/features/profile/presentation/screens/changelog_screen.dart`, her yeni cihaz veya özellik güncellemesinde güncellenmelidir.
    - **Kullanıcı Odaklılık:** Sürüm notları SADECE kullanıcıyı ilgilendiren yeni özellikleri, arayüz değişikliklerini ve hata düzeltmelerini içermelidir.
    - **Teknik Detay Yasağı:** "Ajan dosyaları güncellendi", "Hafıza protokolü eklendi", "Dosya yapısı değişti" gibi sadece geliştiriciyi ilgilendiren teknik detaylar kesinlikle sürüm notlarına eklenmemelidir.
    - **Sıralı Artış:** Her güncelleme sürüm numarasını sıralı bir şekilde artırmalıdır (örneğin 1.2.0 -> 1.2.1).

### Minimum Sürüm İlkesi
Uygulamanın SDK kısıtlamalarına (`sdk: ">=3.0.0 <4.0.0"`) uygun en stabil ve en güncel paket sürüm tercih edilmelidir.

### Veri Sınırları ve Optimizasyon
- **Metin Girişi Sınırları:** Veritabanı şişmesini önlemek ve güvenliği sağlamak için kullanıcıdan alınan tüm metin girişlerine sektör standardında sınırlar konulmalıdır.
    - Konu Başlıkları: Maks 100 karakter
    - Kısa Mesajlar/Yorumlar: Maks 500 karakter
    - Uzun Mesajlar/Geri Bildirimler: Maks 1000 karakter
    - Hata Günlükleri (Ekstra): Maks 10.000 karakter
- **UI Kontrolü:** Tüm `TextField` bileşenlerinde `maxLength` özelliği tanımlanmalı ve kullanıcı sınırlar hakkında bilgilendirilmelidir.

---

<br>

<h2 id="3-arayuz-ve-yerlesim-kurallari">3. ARAYÜZ VE YERLEŞİM KURALLARI</h2>

### Temel Prensipler
- **Önce SafeArea:** Her sayfa (Screen) ve global bileşen, içeriğin sistem çubukları tarafından engellenmesini önlemek için mutlaka bir `SafeArea` widget'ı ile sarmalanmalıdır.
- **Taşma Önleme:** Liste veya dinamik içerik barındıran tüm yerleşimler, farklı ekran boyutlarında `RenderFlex` taşma hatalarını önlemek için kaydırılabilir görünümler (`ListView`, `SingleChildScrollView`) kullanmalıdır.
- **Alt Sayfalar (Bottom Sheets):** Tüm modal alt sayfalar `useSafeArea: true` kullanmalı ve butonların tam görünür olmasını sağlamak için navigasyon çubuğu alanı için dahili dolguyu yönetmelidir.
- **Minimalist ve Simetrik Tasarım:** Tüm kullanıcı arayüzü bileşenleri katı bir simetrik yerleşim yapısını korumalıdır. Simetrik buton yerleşimi, dengeli dolgu ve mükemmel hizalanmış kontroller tartışılamaz bir kuraldır.
- **Kimlik Görüntüleme Önceliği:** Tüm arayüz öğelerinde 'kullanıcı adlarını' gerçek 'tam adlara' veya belirgin profil resimlerine tercih edin. Arayüz kesinlikle işlevsel ve sade tasarlanmalıdır.

### Erişilebilirlik (Ekran Okuyucular)
- Her etkileşimli öğe (`IconButton`, `InkWell`, `ElevatedButton`, vb.), "etiketsiz" olarak okunmasını önlemek için anlamlı bir `semanticsLabel` veya `tooltip` değerine sahip olmalıdır.
- **Çift Etiketleme Yasağı:** Etkileşimli öğelerin gereksiz veya birden fazla semantik düğüme sahip olmadığından emin olun. Gerekirse alt widget'larda `ExcludeSemantics` kullanın.
- Büyük metinler ve özel widget'lar, daha iyi navigasyon için uygun yerlerde `Semantics` widget başlıklarını kullanmalıdır.
- Görseller, görsel içeriğin açıklamasını sağlayan bir `semanticsLabel` değerine sahip olmalıdır.

---

<br>

<h2 id="4-hata-cozum-ve-teknik-bilgi-rehberi">4. HATA ÇÖZÜM VE TEKNİK BİLGİ REHBERİ</h2>

### 📌 Kritik Teknik Notlar
- **PocketBase Veri Tipleri:** `RecordModel` üzerindeki `created` ve `updated` alanları **String** tipindedir. Bu alanlar üzerinde doğrudan `toLocal()` çağrılamaz. Her zaman `DateTime.parse()` ile dönüştürülmelidir.
- **Null Safety:** PocketBase'den gelen `expand` verileri her zaman opsiyoneldir. Null kontrolü yapılmadan listelere veya fieldlara erişilmemelidir.
- **PocketBase Değerleri:** `RecordModel` verilerine `.email` veya `.data['field']` yerine `getStringValue`, `getBoolValue`, `getDataValue` ile erişin.
- **WebView ve Linkler:** Çoğu sistemde (Ajan güvenlik kilitleri, Iframe platformları, Android > 13 CustomTabs) `canLaunchUrl` metodu `false` döner. Bu yüzden `canLaunchUrl` yerine doğrudan bypass ederek `launchUrl` kullanın. İşlem catch'e düşerse `PlatformDefault` parametresiyle deneyin.

### 🐍 Python ve Bot Geliştirme Notları (Ubuntu 24.04)
- **Sunucu Mimari Notu:** Sistem Ubuntu 24.04 üzerinde Terminal/CLI (Headless) olarak çalışmaktadır.
- **Python Pip Kısıtlamaları:** Ubuntu 24.04'te sistem paketlerini korumak için `pip install` komutları kilitlidir. DAİMA `--break-system-packages` ve `--ignore-installed` argümanları kullanılmalıdır.
- **Selenium ve Snap Tarayıcıları:** Ubuntu 24.04'te Chromium doğrudan işletim sistemine kurulmaz, kilitli bir **Snap** konteynerine kurulur (`/snap/bin/chromium`).
- **Zamanlayıcılar:** Bot süreçleri Python schedule kütüphanesi yerine `bot_manager.py` içinde işletim sistemi tabanlı entegre `crontab` üzerinden işletilecektir.

---

<br>

<h2 id="5-bagimlilik-envanteri-ve-surum-takibi">5. BAĞIMLILIK ENVANTERİ VE SÜRÜM TAKİBİ</h2>

Projede kullanılan kritik `pubspec.yaml` paket listesi:
*   `flutter_riverpod` (^2.6.1) - Durum Yönetimi
*   `pocketbase` (^0.20.0) - Veritabanı ve Auth
*   `firebase_core`, `firebase_messaging` - Anlık Bildirim (Push)
*   `flutter_secure_storage`, `shared_preferences` - Şifreli ve Yerel Veri Kaydı
*   `share_plus` - Sosyal Paylaşım Entegrasyonu
*   `ffmpeg_kit_flutter_new_https`, `audioplayers`, `just_audio` - Medya İşlemleri

**Kural:** Paketi projeye dahil etmeden önce muhakkak `google_search` kullanarak pub.dev'deki en son halini teyit edin. Statik bilgiye güvenmeyin.

---

<br>

<h2 id="6-sistem-bilesenleri-ve-servis-katalogu">6. SİSTEM BİLEŞENLERİ VE SERVİS KATALOĞU</h2>

*   **PocketBaseService:** (`lib/core/services/pocketbase_service.dart`) Ana veritabanı istemcisi.
*   **SecurityService:** (`lib/core/services/security_service.dart`) Cihaz bütünlüğü, ekran koruma.
*   **ExpandableText:** (`lib/core/widgets/expandable_text.dart`) Uzun metin ("daha fazla oku") yönetimi.
*   **Admin Özelliği:** (`lib/features/admin/`) Sistem yöneticileri için yönetim araçları ve Log ekranı.
*   **Campaigns Özelliği:** (`lib/features/campaigns/`) Güncel Kampanyaların çekildiği merkez. Performansı artırmak için PocketBase listesi `SharedPreferences` ile önbelleklenmiş (`12 Saat`) yerel bir arama sistemine sahiptir.

---

<br>

<h2 id="7-proje-yol-haritasi-ve-yapilacaklar">7. PROJE YOL HARİTASI VE YAPILACAKLAR</h2>

**✅ Yakın Zamanda Tamamlananlar (Özet)**
*   Bot, "Web sayfasında görüntüle" mantığını bankaların orijinal sayfalarıyla entegrasyonlayarak v1.6.0 haline getirdi.
*   Kampanya listesinde 12 Saatlik `SharedPreferences` önbelleği kurularak veritabanı okuma maliyetleri düşürüldü (v1.6.1).
*   Bot Yöneticisine otonom Linux Crontab arayüzü eklendi (v1.6.1).
*   Kampanya listesinde *sağa sola Swipe* (kaydırma) ile kategoriler arası gezinme sağlandı (v1.6.2).
*   Detay sayfasında `PageView` kullanılarak kampanyalar arasında akıcı hızlı geçiş desteği eklendi ve SharePlus ile Paylaş butonu getirildi (v1.6.2).

**🛠️ Devam Eden / Bekleyen Görevler**
*   Süresi dolan kampanyaların otomatik olarak "Pasif" işaretlenmesi için bir cron-job botu entegre edilecek.
*   Farklı kampanya siteleri için Modüler/Genel bir Bot adaptörü yazılacak.
*   Çoklu dil desteği eklenecek.
*   Topluluk odaklı tema arayüzü seçenekleri eklenecek.
