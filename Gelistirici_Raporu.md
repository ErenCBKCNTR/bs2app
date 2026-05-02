# Blind Social Geliştirici ve Güvenlik Analiz Raporu

Bu rapor, Blind Social uygulamasının web sürümünde karşılaşılan LiveKit ses odalarına katılım sorununu, performans/veritabanı analizlerini ve yeni özellik tavsiyelerini diğer Yapay Zeka (AI) ajanının anlayabileceği teknik formatta sunmaktadır.

## 1. Web Sürümü LiveKit Mikrofon İzni (minified:abO) Hatası Analizi

**Sorun:**
Web sürümünde (özellikle mobil tarayıcılarda) sesli sohbet odasına katılmak istendiğinde `Instance of 'minified:abO'` veya bağlantı reddi hatası alınıyor. Kullanıcı mikrofon izni vermiş olsa bile odaya sadece dinleyici olarak katılabiliyor.

**Kök Neden (Root Cause):**
`lib/features/chat/presentation/screens/active_voice_room_screen.dart` dosyasındaki `_connectToRoom` fonksiyonu içerisinde web ortamı için özel bir "pre-flight" (bağlantı öncesi) mikrofon izin kontrolü yapılmaktadır:

```dart
// PRE-FLIGHT MICROPHONE CHECK FOR WEB
if (kIsWeb) {
  try {
    final stream = await webrtc.navigator.mediaDevices.getUserMedia({'audio': true});
    for (var track in stream.getTracks()) {
      track.stop(); // ALARM: Bu işlem track'i hemen kapatır!
    }
    // ...
```
1. Bu işlem sırasında `flutter_webrtc` doğrudan tarayıcının MediaDevices API'sini çağırır.
2. Mobil tarayıcılar (özellikle iOS Safari ve Android Chrome), kullanıcı etkileşimi (tıklama) ile mikrofon talebi arasında en ufak bir gecikme olduğunda veya ardışık mikrofon isteklerinde güvenliği sıkılaştırır (Autoplay Policy / Secure Context).
3. Pre-flight'ta mikrofon alınıp hemen `track.stop()` yapıldığında, ardından hemen çalışan `_room!.connect` ve `_room!.localParticipant?.setMicrophoneEnabled(true)` LiveKit fonksiyonları çalışırken tarayıcı donanım kanalını hızlıca serbest bırakmamış olabilir veya ikinci isteği bir spam olarak algılayıp `DOMException` fırlatabilir. Minified DOMException hatası (`minified:abO`), `NotAllowedError` veya `InvalidStateError` hatalarına denk gelmektedir.

**Çözüm Yönergesi (AI Ajanına Talimat):**
* `active_voice_room_screen.dart` dosyasından `kIsWeb` kontrolüne bağlı olan gereksiz **Pre-flight mikrofon testini tamamen silin.**
* LiveKit'in kendi iç yapısı (`_room.connect` ve `setMicrophoneEnabled`) mikrofon izinlerini istemek ve yönetmek konusunda halihazırda endüstri standartlarındadır. Web için fazladan `flutter_webrtc` çağrısı yapmak yerine izinleri tamamen LiveKit'e bırakın.
* Mobil cihazlarda donanımsal engelleri aşmak için `connectOptions` içinde `audio` değerinin doğru yapılandırıldığından emin olun.

---

## 2. Veritabanı ve Performans Taraması

**A. Veritabanı Web Uyumsuzluğu (Kritik Uyarı):**
Uygulamada veritabanı olarak PocketBase kullanılsa da, yerel kayıtların tutulması için `lib/features/radio/data/recording_database.dart` dosyasında `sqflite` paketi kullanılmaktadır.
* `sqflite` paketi standart olarak **Web platformunu desteklemez.**
* Uygulamanın web sürümünde radyo veya kayıt özellikleri tetiklendiğinde `MissingPluginException` veya direkt çökme (crash) meydana gelecektir.
* **Çözüm Talimatı:** AI ajanının `sqflite` bağımlılığını `sqflite_common_ffi_web` ile sarmalaması veya tamamen web uyumlu olan `drift`, `hive` veya `isar` veritabanlarından birine geçiş yapması gerekmektedir. Şimdilik web platformunda `kIsWeb` kontrolü yaparak bu servisin çağrılmasını engelleyebilirsiniz.

**B. Durum Yönetimi (State Management) Bellek Sızıntıları:**
Projede Riverpod kullanılmaktadır. Ancak ekran yönlendirmelerinde, özellikle odadan çıkışlarda `RoomDisconnectedEvent` dinleyicisinde state temizleme işlemleri `dispose` fonksiyonlarında dikkatli yapılmalıdır. `AppLogger.instance.logs` 500 adet ile sınırlandırılmış ki bu iyi bir performans önlemi, ancak chat detay ekranlarında uzun mesaj listelerinin `ListView.builder` ile yüklenirken resim/ses cache'lerinin bellek şişirmemesi için pagination uygulanmalıdır.

---

## 3. Yeni Özellik Tavsiyeleri ve Sistem Geliştirmeleri

**Tavsiye 1: LiveKit Ağ Kalitesi Göstergesi (Network Quality Indicator)**
Görme engelli kullanıcılar, bağlantı sorunları yaşadıklarında problemin kendi internetlerinden mi yoksa sunucudan mı kaynaklandığını anlayamayabilirler.
* **Uygulama:** LiveKit'in `NetworkQualityChangedEvent` olayını dinleyerek kullanıcının internet bağlantı kalitesi düştüğünde sesli geri bildirim ("Bağlantınız zayıf, sesler kesilebilir") verilmesi sisteme eklenebilir.

**Tavsiye 2: Gelişmiş Ses Kesintisi Yönetimi (`audio_session`)**
Telefon geldiğinde veya başka bir uygulama medyası çalıştığında, sesli odanın davranışını yönetmek zordur.
* **Uygulama:** Projeye `audio_session` paketini ekleyerek, sesli sohbetteyken arka plan seslerini kısma (ducking) veya telefon aramalarında odadaki sesi otomatik olarak duraklatma (pause) kuralları yapılandırılmalıdır.

**Tavsiye 3: Web Sürümü İçin Secure Context (HTTPS) Kontrolü**
Mikrofonun çalışması için uygulamanın kesinlikle HTTPS veya `localhost` üzerinde çalışması gerekmektedir. Eğer uygulama `http://` ile sunuluyorsa tarayıcılar mikrofonu otomatik olarak bloklar. Geliştirme ortamı dahi olsa HTTPS zorunluluğu dokümante edilmelidir.

## Sonuç
Yapay Zeka Ajanına son not:
1. `active_voice_room_screen.dart` dosyasındaki Web Pre-flight mikrofon kontrolünü kaldır.
2. `sqflite` kütüphanesini kullanan `recording_database.dart` dosyasındaki fonksiyonları `kIsWeb` durumuna göre sınırla.
3. Bu değişiklikler sağlandığında Web sürümündeki sorun çözülecektir.
