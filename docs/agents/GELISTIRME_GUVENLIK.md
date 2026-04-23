# Geliştirme ve Güvenlik Standartları

## Güvenlik Protokolleri
- **Ekran Koruması:** Desteklenen platformlarda (Android) ekran görüntüsü alınmasını ve ekran kaydı yapılmasını önlemek için `main.dart` içerisinde `SecurityService().protectScreen()` mutlaka çağrılmalıdır.
- **Çevre Bütünlüğü:** Uygulama, başlatma sırasında `SecurityService` aracılığıyla cihaz bütünlüğü kontrollerini (root/jailbreak tespiti) yapmalıdır. Bir güvenlik ihlali tespit edilirse hassas özellikler devre dışı bırakılmalıdır.
- **Veri Güvenliği:** Hassas veriler (JWT token'ları, kullanıcı ID'leri, özel anahtarlar) düz metin olarak (SharedPreferences) saklanmamalıdır. Verilerin şifrelenmiş olarak saklanmasını sağlamak için `PocketBaseService` üzerinden `FlutterSecureStorage` kullanın.
- **Tersine Mühendislik Önleme:** Tüm üretim sürümleri Flutter'ın gizleme (obfuscation) bayraklarını kullanmalıdır: `flutter build apk --obfuscate --split-debug-info=./debug-info`. Bu işlem, sınıfları ve metodları okunamaz diziler olarak yeniden adlandırır.
- **Admin Rotası Güvenliği:** AdminService geçmişte sahibini e-posta adresiyle yetkilendiren bir geri dönüş mekanizmasına sahipti. Bu artık KESİNLİKLE KISITLANMIŞTIR. `AdminService().isAdmin()` sadece `user.data['role'] == '0'` kontrolünü yapmalıdır. Ayrıca, yönetici paneline ait tüm ekranlar ve rotalar, standart bir kullanıcının modüle haksız yere girmesi durumunda hiçbir verinin çekilmemesini ve UI'ın oluşturulmamasını sağlamak için `build` bağlamlarını `if (!AdminService().isAdmin()) return AccessDeniedWidget();` ile sarmalamalıdır.

## Veritabanı ve Veri Standartları
- **Veritabanı Bütünlüğü:** Veritabanı mantığında yapılan her türlü değişiklikle birlikte `pb_schema.json` dosyasını her zaman güncel tutmalısınız. **KRİTİK:** Yeni bir alan eklediğinizde veya veritabanı mantığını değiştirdiğinizde, bu değişiklikleri yansıtmak için `pb_schema.json` dosyasını derhal güncellemelisiniz.
- **Sıkılaştırılmış Veritabanı Kuralları:** `pb_schema.json`, tüm listeleme/görüntüleme işlemleri için `@request.auth.id != ""` kuralını ve tüm koleksiyonlar için katı sahibi tabanlı güncelleme/silme kurallarını zorunlu kılmalıdır.
- **API Denetim Başlıkları:** Her API isteği, sunucu tarafında denetim ve anomali tespiti yapılabilmesi için `PocketBaseService` başlıkları aracılığıyla cihaz meta verilerini (ID, Model, OS) içermelidir.

## Geliştirme Standartları
- **Senkronizasyon Önceliği:** Ses kayıt özelliklerinde, başlatma/durdurma senkronizasyonunun kullanıcı etkileşimiyle mümkün olduğunca eşleşmesini sağlamak için agresif FFmpeg bayrakları (düşük tampon, hızlı probe) kullanın.
- **Özellik İzolasyonu:** Yeni bir bağımsız özellik uygulanacağında, modüler ve sürdürülebilir bir kod tabanı sağlamak için kendi dizininde (örneğin `lib/features/yeni_ozellik/`) oluşturulmalıdır.
- **OAuth Özel Sekme Geri Dönüşü (Android):** `window.close()` ve `closeInAppWebView()` fonksiyonları, Özel Sekmeler (Custom Tabs) içindeki Android 13/14+ güvenlik politikaları nedeniyle temelden engellenmiştir.
    - Yol: `AndroidManifest.xml`, `<data android:scheme="blindsocial" android:host="auth" />` intent'ini içermelidir.
    - Kurtarma: Dahili loopback sunucumuz tarafından sunulan HTML, Android işletim sistemini uygulamamızı ön plana çıkarmaya zorlamak için `window.location.replace("blindsocial://auth");` kullanmalıdır.
- **Değişiklik Günlüğü (Changelog) Güncellemeleri:** `lib/features/profile/presentation/screens/changelog_screen.dart`, her yeni cihaz veya özellik güncellemesinde güncellenmelidir.
    - **Kullanıcı Odaklılık:** Sürüm notları SADECE kullanıcıyı ilgilendiren yeni özellikleri, arayüz değişikliklerini ve hata düzeltmelerini içermelidir.
    - **Teknik Detay Yasağı:** "Ajan dosyaları güncellendi", "Hafıza protokolü eklendi", "Dosya yapısı değişti" gibi sadece geliştiriciyi ilgilendiren teknik detaylar kesinlikle sürüm notlarına eklenmemelidir.
    - **Sıralı Artış:** Her güncelleme sürüm numarasını sıralı bir şekilde artırmalıdır (örneğin 1.2.0 -> 1.2.1).
