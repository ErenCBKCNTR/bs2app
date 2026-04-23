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

## 🚀 Geliştirme Öncesi Kontrol Listesi
1. [ ] Yeni eklenen TextField bileşenlerinde `maxLength` var mı? (Günevlik Protokolü)
2. [ ] PocketBase Record objelerinden tarih okunurken `DateTime.parse` kullanıldı mı?
3. [ ] `expand` edilen verilerde null kontrolü yapıldı mı?
4. [ ] Yeni bağımlılık eklendiyse `BAGIMLILIK_ENVANTERI.md` güncellendi mi?
