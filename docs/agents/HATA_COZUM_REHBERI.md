# 🛠️ Hata Çözüm ve Teknik Bilgi Rehberi

Bu dosya, projede karşılaşılan teknik hataların kök nedenlerini, çözümlerini ve gelecekte benzer hataların yapılmaması için alınması gereken önlemleri içerir. Her geliştirme öncesi bu dosyadaki "Kritik Teknik Notlar" bölümü kontrol edilmelidir.

## 📌 Kritik Teknik Notlar (Her Zaman Kontrol Et)

- **PocketBase Veri Tipleri:** `RecordModel` üzerindeki `created` ve `updated` alanları **String** tipindedir. Bu alanlar üzerinde doğrudan `toLocal()` gibi `DateTime` metodları çağrılamaz. Her zaman `DateTime.parse()` ile dönüştürülmelidir.
- **Null Safety:** PocketBase'den gelen `expand` verileri her zaman opsiyoneldir. Null kontrolü yapılmadan listelere veya fieldlara erişilmemelidir.
- **Karakter Sınırları:** Tüm kullanıcı girişlerinde (özellikle blog, mesaj ve geri bildirim) `GELISTIRME_GUVENLIK.md` dosyasındaki karakter sınırları ve `maxLength` kuralı zorunludur.

---

## 📜 Tarihçe ve Çözülen Hatalar

### [23 Nisan 2026] - Release Build / String to DateTime Hatası
- **Hata Mesajı:** `Error: The method 'toLocal' isn't defined for the type 'String'.`
- **Dosya:** `lib/features/admin/presentation/screens/feedback_detail_screen.dart`
- **Kök Neden:** PocketBase SDK'sında `RecordModel.created` alanı `String` döndürmesine rağmen, kod içerisinde `DateTime` objesiymiş gibi davranılarak `toLocal()` metodu çağrılmış. Geliştirme (Debug) modunda bazen fark edilmese de `flutter build apk --release` aşamasında derleyici (AOT) bu hatayı yakalar.
- **Çözüm:** `feedback.created.toLocal()` ifadesi `DateTime.parse(feedback.created).toLocal()` olarak güncellendi.
- **Ders:** Veritabanından gelen tarih alanlarını kullanırken tip dönüşümüne (parsing) her zaman dikkat edilmelidir.

---

### [23 Nisan 2026] - Release Build / Const ve Import Hataları
- **Hata Mesajı:** `Error: Not a constant expression.` ve `Error: The method 'canLaunchUrl' isn't defined.`
- **Dosya:** `lib/features/campaigns/presentation/screens/campaigns_screen.dart`
- **Kök Neden:** 
  1. `EdgeInsets.all()` içinde değişken (`displayImageUrl == campaignImage`) kullanılmasına rağmen başına `const` eklenmiş. Const ifadeleri çalışma zamanı (runtime) değişkenlerini kabul etmez.
  2. `canLaunchUrl` ve `launchUrl` metodları kullanılmadan önce `url_launcher` paketi import edilmemiş.
- **Çözüm:** 
  1. Dinamik kontrol içeren widget'ların başındaki `const` ifadeleri kaldırıldı.
  2. `import 'package:url_launcher/url_launcher.dart';` satırı eklendi.
- **Ders:** Widget ağacında dinamik değerler kullanılıyorsa üst widget'larda `const` kullanımı dikkatle incelenmelidir. Paket metodları çağrılmadan önce import listesi kontrol edilmelidir.

---

### [23 Nisan 2026] - Admin / Yetki ve Bot URL Hataları
- **Hata 1:** `NoSuchMethodError: RecordModel has no getter 'email'`.
  - **Çözüm:** `user.email` yerine `user.getStringValue('email')` kullanıldı. AdminService güncellendi.
- **Hata 2:** Botun `/sektorler/` gibi alt sayfalardaki kampanyaları görememesi.
  - **Çözüm:** Link yakalama mantığı `startswith` yerine `in` kontrolüne ve `urljoin` optimizasyonuna geçirildi.
- **Ders:** PocketBase SDK objelerine erişirken her zaman `getStringValue`, `getBoolValue` gibi tip güvenli metodlar tercih edilmelidir. Bot scraping mantığı site yapısındaki değişimlere karşı her zaman "esnek" (greedy) tasarlanmalıdır.

---

## 🚀 Geliştirme Öncesi Kontrol Listesi
1. [ ] Yeni eklenen TextField bileşenlerinde `maxLength` var mı? (Günevlik Protokolü)
2. [ ] PocketBase Record objelerinden tarih okunurken `DateTime.parse` kullanıldı mı?
3. [ ] `expand` edilen verilerde null kontrolü yapıldı mı?
4. [ ] Yeni bağımlılık eklendiyse `BAGIMLILIK_ENVANTERI.md` güncellendi mi?
5. [ ] **[YENİ]** Dinamik değer alan padding veya margin alanlarında `const` kaldırıldı mı?
6. [ ] **[YENİ]** Dış kütüphane metodları (url_launcher vb.) için importlar eksiksiz mi?
7. [ ] **[YENİ]** PocketBase `json` tipi alanlarda `maxSize` tanımlandı mı?
8. [ ] **[YENİ]** `RecordModel` verilerine `.email` veya `.data['field']` yerine `getStringValue` ile erişildi mi?

---

## 🐍 Python ve Bot Geliştirme Notları
- **Bağımlılıklar:** Her bot klasörü (`bots/bot_name/`) kendi `requirements.txt` dosyasını içermelidir. Sunucuda kurulum yapmadan önce mutlaka versiyon kontrolü yapılmalıdır.
- **Scraping Etiği:** Botlar taranacak siteyi yormamak için (Denial of Wallet/Service önlemek adına) istekler arasına `time.sleep()` koymalıdır.
- **Dinamik İçerik:** JavaScript ile yüklenen siteler için `requests` yerine `Selenium` veya `Playwright` gerekebilir. Şimdilik `BeautifulSoup` standart olarak belirlendi.
- **Database Bağlantısı:** Botlar PocketBase'e admin token ile veya gizli bir API user ile bağlanmalıdır. Şifreler çevre değişkenleri (environment variables) üzerinden geçilmelidir.

---

## 📱 Flutter Arayüz Geliştirme Notları
- **Image.network ve Padding:** `Image.network` widget'ı doğrudan `padding` parametresi almaz. Görsele boşluk vermek gerekiyorsa mutlaka `Padding` widget'ı ile sarmalanmalıdır. (Hata: `No named parameter with the name 'padding'`).
- **Semantics:** Erişilebilirlik için butonlara ve önemli görsellere mutlaka `Semantics` widget'ı veya `label` parametresi eklenmelidir.
