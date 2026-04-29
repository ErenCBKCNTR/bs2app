# GÖREV PANOSU (TRELLO BENZERİ UYGULAMA) YOL HARİTASI

**Önemli Kural:** Bu özellik tamamen bitene kadar Yapay Zeka Ajanı, yeni bir geliştirme adımına geçmeden önce sürekli olarak bu dosyayı okumalı ve analiz etmelidir. Eksik bir şey kalmadığından emin olunduğunda ve proje tamamlandığında bu dosya silinebilir.

## 1. Veritabanı ve Şema Güncellemeleri (PocketBase)
- [ ] `task_boards` koleksiyonuna favoriler (yıldızlı panolar) için alan eklenecek.
- [ ] `task_lists` koleksiyonuna daraltma/genişletme (isCollapsed) ve başa tutturma (isPinned) durumlarını yönetecek mantık veya alanlar eklenecek.
- [ ] `task_items` (Kartlar) koleksiyonuna eklenecekler:
  - Otomatik atanacak olan "Kart Numarası" (Örn: #1001).
  - Özelleştirilebilir "Etiketler" (Tags/Labels) için bir yapı.
- [ ] `task_checklists` (Kontrol listesi) adında yeni bir koleksiyon eklenecek (Kart içindeki alt görevleri tutmak için).

## 2. Pano ve Liste Yapısı
- [ ] Panolara "Favorilere Ekle/Yıldızla" butonu ve yalnızca favorileri gösterme filtresi eklenecek.
- [ ] Listelerin karmaşık görünmemesi için genişletilebilir/daraltılabilir (Accordion tarzı) bir arayüz tasarlanacak.
- [ ] Listelerin önem sırasına göre yukarı/aşağı taşınabilmesi ve başa tutturulabilmesi (Pin) sağlanacak.

## 3. Kart ve Görev Yönetimi
- [ ] Yeni kart eklendiğinde sistemin numaralandırma yapması sağlanacak.
- [ ] Kart içerisine onay kutulu kontrol listesi (checklist) arayüzü yapılacak.
- [ ] Kontrol listesindeki görevler işaretlendikçe tamamlanma yüzdesi hesaplanacak ve ekran okuyucu (`SemanticsService`) ile anlık olarak duyurulacak (Örn: "4 işten 1'i bitti, yüzde 25 tamamlandı").
- [ ] Kartlara açıklama ve kullanıcıların oluşturup silebildiği renkli etiketler atanabilecek.
- [ ] Kartı "Başka Listeye Taşı" (Taşıma İşlemi) seçeneği eklenecek.
- [ ] Pano içerisinde etiket ve kart ismine göre çalışan arama/filtreleme özelliği yapılacak.

## 4. İşbirliği ve Paylaşım
- [ ] Panoya başka kullanıcıları davet etme (Ortak çalışma) altyapısı geliştirilecek.
- [ ] Bir kartın içerisine panoya üye olan kişilerden sorumlular (assignees) atanabilecek.
- [ ] Kartı dışarıyla (`SharePlus` veya Deep Link ile) link olarak paylaşma butonu eklenecek.

## 5. Arayüz (UI/UX) ve Erişilebilirlik
- [ ] Listeler alt alta dizilecek. Liste açıldığında, içerisindeki kartlar kütüphane raflarındaki kitaplar gibi yan yana (GridView / Wrap kullanılarak) dizilecek.
- [ ] Görme engelliler için optimize edilmiş; tüm taşıma, check etme, listeyi açma gibi işlemler SemanticsService ile desteklenip %100 erişilebilir hale getirilecek.
- [ ] Hem mobil arayüz şıklığı sağlanacak, hem de tablet/büyük ekranlar için duyarlı (Responsive) bir yapı gözetilecek.
