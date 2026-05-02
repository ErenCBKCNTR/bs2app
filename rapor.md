# Blind Social Uygulaması Performans ve Güvenlik Analiz Raporu

## Yönetici Özeti (Executive Summary)
Uygulamanın giriş sayfasından çıkışına kadar, özellikle Web ve Android platformları arasındaki uyumsuzluklar, performans sorunları (takılmalar, donmalar) ve veritabanı güvenlik açıkları incelenmiş olup, kapsamlı çözüm önerileri sunulmuştur. Bu rapor hem teknik ekibin uygulayabileceği somut adımları hem de danışmanlık perspektifini içermektedir.

## 1. Performans Sorunları ve Takılmalar (UI/UX Janks)

### a) Web ve Mobil İçin ListView/Listeleme Performansı
Uygulamada 30'dan fazla dosyada `ListView.builder` kullanılmaktadır. Liste içi öğeler karmaşık widget ağaçları (örneğin blog, mesaj listeleri) içerdiğinde, ekran okuyucular ve render motoru zorlanabilir.
- **Sorun:** Çok sayıda görsel veya detay içeren (özellikle `blog_screen.dart`, `my_blog_posts_screen.dart`, `chat_detail_screen.dart` gibi) ekranlarda state güncellemeleri ve görseller aynı anda yüklendiğinde, UI Thread'de darboğaz (jank) yaşanır. Web ortamında DOM güncellemeleri daha maliyetlidir.
- **Çözüm:**
  - Web ve Mobil platformlar için Pagination (sayfalama) ve Infinite Scrolling yapıları optimize edilmelidir.
  - ListView öğelerinde mutlaka `addAutomaticKeepAlives: false` ve `addRepaintBoundaries: true` özellikleri kullanılmalı, büyük listeler `SliverList` (CustomScrollView) ile refactor edilmelidir.

### b) Veritabanı (PocketBase) Gereksiz Sorgu Çağrıları
Android uygulaması, arka planda PocketBase servisini dinlerken ("Real-time Updates") gereksiz abonelikler (subscriptions) nedeniyle cihaz bataryasını ve CPU'sunu tüketebilir.
- **Sorun:** Servis dinleyicileri (listener) sayfa kapatıldığında (`dispose` metodunda) düzgün şekilde sonlandırılmıyorsa (unsubscribe), sayfa tekrar açıldığında çoklu dinleyiciler birikerek arka arkaya aynı sorguyu/aksiyonu tetikler.
- **Çözüm:** Tüm Riverpod veya StatefulWidget'ların `dispose` metodunda PocketBase abonelikleri temizlenmeli (`pb.collection('...').unsubscribe()`). Provider'larda `autoDispose` kullanılmalıdır.

## 2. Web Tarafında Sesli Sohbet Bağlantı Sorunu (LiveKit)

### a) Sürekli Yüklenme İkonu (Endless Loading Spinner) Sorunu
Web tarafında, sesli odaya bağlanırken sürekli "Yükleniyor" ikonunun görünmesi ve odanın bağlanmaması platforma özgü donanım izinleri veya yetersiz SDK güncellemeleriyle ilgilidir.
- **Sorun:** `ActiveVoiceRoomScreen` içerisinde `_connectToRoom` metodu incelendiğinde, Web tarafında bağlanırken oluşan bazı hataların (örneğin WebRTC veya mikrofon izni hataları) try-catch bloğunda uygun bir şekilde `setState` tetiklemediği, uygulamanın sessizce başarısız (silent fail) olduğu gözlemlenmiştir.
- **Çözüm:**
  - `livekit_client` için kütüphane WebRTC özelliklerinin tarayıcı izinlerini (HTTPS zorunluluğu) sağlaması garanti edilmelidir. (Bağlantı sırasında Web ortamında mikrofon izni `dart:html` veya modern browser API'leri ile açıkça istenmelidir, çünkü `permission_handler` Web tarafında çalışmaz).
  - Tarayıcı ortamında eksik olan token atama sorunlarına karşı, JWT token ve LiveKit URL yönlendirmelerinin `wss://` formatında doğru ayarlandığı Web ortamına uygun fallback mekanizmaları oluşturulmalıdır.

## 3. Platform Çakışmaları (Web vs Android)

### a) `kIsWeb` Kontrolleri
Uygulamada Web ve Mobil ortamlarının ayrılması için `kIsWeb` ve `Platform.is...` yapıları kullanılmıştır. Fakat `Platform.is...` kullanımı Web için direkt hata fırlatır çünkü `dart:io` Web üzerinde desteklenmez.
- **Sorun:** Auth ekranında veya servis sınıflarında Web ortamında yanlışlıkla `Platform.isAndroid` tetiklenirse, uygulama Web'de tamamen donabilir (Crash).
- **Çözüm:** `Platform.is...` sorguları yapılmadan önce mutlaka `!kIsWeb` şartı kontrol edilmelidir. `SecurityService` gibi dosyalardaki bu kullanımlar standartlaştırılmalıdır (Uygulamada bazı yerlerde düzgün yapılmış olsa da tam kontrol şarttır).

## 4. Veritabanı Güvenlik Açıkları (PocketBase Schema Security)

`pb_schema.json` incelendiğinde oldukça kritik güvenlik açıkları tespit edilmiştir.

### a) Herkese Açık Görüntüleme Sorunları (Unprotected List/View Rules)
- **Sorun:** Çoğu koleksiyonda (mesajlar, görev panoları, yorumlar) `listRule` ve `viewRule` kuralı sadece `@request.auth.id != ''` olarak bırakılmıştır.
  - *Bu ne demek?* Uygulamaya giriş yapmış **herhangi bir** kullanıcı, tüm veritabanındaki mesajlara veya özel verilere "API üzerinden" bir istek atarak erişebilir. Dışarıdan yetkisi olmayan bir kullanıcı bile basit bir token ile başkalarının mesajlarını okuyabilir.
- **Çözüm:** Koleksiyonlara göre erişim kuralları sınırlandırılmalıdır:
  - `collection_messages` (Mesajlar): `chat_id.participants ~ @request.auth.id` (Sadece o sohbetin içindeki kişiler listelemeli/okumalı).
  - `task_boards` (Görevler): Şu anki kural nispeten doğru (`owner_id = @request.auth.id || members ~ @request.auth.id`), ancak benzer katı kurallar tüm koleksiyonlara uygulanmalıdır.

### b) Veri Manipülasyonu (Unprotected Create/Update Rules)
- **Sorun:** `updateRule: @request.auth.id != ''` şeklinde bırakılan kurallar, herhangi bir kullanıcının başkasının mesajını, profilini veya verisini değiştirmesine olanak tanır.
- **Çözüm:**
  - Mesaj güncellemeleri için: `sender_id = @request.auth.id`
  - Profil güncellemeleri için: `id = @request.auth.id` (Sadece kendi hesabını güncelleyebilme).

## Sonuç ve Acil Eylem Planı (Actionable Steps)
1. **Güvenlik (Kritik):** PocketBase Admin panelinden tüm tabloların (Collections) API Rules kısımları, "Sadece veri sahibi okuyabilir/düzenleyebilir" mantığına göre hemen güncellenmelidir.
2. **Performans:** ListView sayfalarındaki ağır rendering süreçleri için `addRepaintBoundaries: true` eklenmeli ve Web'deki Scroll (Kaydırma) fizik problemleri düzeltilmelidir.
3. **Web Sesli Sohbet (LiveKit):** Web platformunda `permission_handler` çalışmadığı için, Web'e özel tarayıcı mikrofon izni isteme kodu (JS interop veya Web uyumlu paket) entegre edilmelidir. Hata fırlatıldığında `Loading` ikonunun kaybolması için try-catch finally bloklarına `_isConnected = false` ve mesaj eklenmelidir.
