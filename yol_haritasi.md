# GÖREV PANOSU (TRELLO BENZERİ UYGULAMA) YOL HARİTASI

**Önemli Kural:** Bu özellik tamamen bitene kadar Yapay Zeka Ajanı, yeni bir geliştirme adımına geçmeden önce sürekli olarak bu dosyayı okumalı ve analiz etmelidir. Eksik bir şey kalmadığından emin olunduğunda ve proje tamamlandığında bu dosya silinebilir.

## 1. Veritabanı ve Şema Güncellemeleri (PocketBase)
- [x] `task_boards` koleksiyonuna favoriler (yıldızlı panolar) için alan eklenecek.
- [x] `task_lists` koleksiyonuna daraltma/genişletme (isCollapsed) ve başa tutturma (isPinned) durumlarını yönetecek mantık veya alanlar eklenecek.
- [x] `task_items` (Kartlar) koleksiyonuna eklenecekler:
  - Otomatik atanacak olan "Kart Numarası" (Örn: #1001).
  - Özelleştirilebilir "Etiketler" (Tags/Labels) için bir yapı.
- [x] `task_checklists` (Kontrol listesi) adında yeni bir koleksiyon eklenecek (Kart içindeki alt görevleri tutmak için).

## 2. Pano ve Liste Yapısı
- [x] Panolara "Favorilere Ekle/Yıldızla" butonu ve yalnızca favorileri gösterme filtresi eklenecek.
- [x] Listelerin karmaşık görünmemesi için genişletilebilir/daraltılabilir (Accordion tarzı) bir arayüz tasarlanacak.
- [x] Listelerin önem sırasına göre yukarı/aşağı taşınabilmesi ve başa tutturulabilmesi (Pin) sağlanacak.

## 3. Kart ve Görev Yönetimi
- [x] Yeni kart eklendiğinde sistemin numaralandırma yapması sağlanacak.
- [x] Kart içerisine onay kutulu kontrol listesi (checklist) arayüzü yapılacak.
- [x] Kontrol listesindeki görevler işaretlendikçe tamamlanma yüzdesi hesaplanacak ve ekran okuyucu (`SemanticsService`) ile anlık olarak duyurulacak (Örn: "4 işten 1'i bitti, yüzde 25 tamamlandı").
- [x] Kartlara açıklama ve kullanıcıların oluşturup silebildiği renkli etiketler atanabilecek.
- [x] Kartı "Başka Listeye Taşı" (Taşıma İşlemi) seçeneği eklenecek.
- [x] Pano içerisinde etiket ve kart ismine göre çalışan arama/filtreleme özelliği yapılacak.
- [x] Panolar listesinde panoları renklendirerek kare kutular halinde (GridView) gösterme.
- [x] Panolar sayfasında pano içi arama yapabilme.
- [x] Pano silme, güncelleme gibi özellikleri erişilebilirlik bağlamında Semantics action olarak entegre etme.
- [x] Pano detay/içerik sayfasında görsel modernleştirme ve liste arka planlarını renklendirme.
- [x] Pano içerisinde listelerin tümü açılışta kapalı (daraltılmış) gelecek. Listeler ve görevler arası gezinmede Semantics ve DoubleTap özellikleri geliştirilecek.
- [x] Pano içi liste ve görev işlemleri için ekran okuyucu uyumlu "İşlemler Menüsü (CustomSemanticsAction)" yapısı entegre edilecek.
- [x] Ekran okuyucu ile görev tamamlanma/eklenme bildirimleri sırasında sayfanın yenilenmesi nedeniyle oluşan konuşmanın yarım kalması sorunu, "arkaplanda sessiz yükleme" mantığı ile çözülecek.
- [x] Görev kartlarına odaklanıldığında ekran okuyucunun düzenleme/görüntüleme için çift tıklama ve işlemler menüsü bildirimlerini okuması sağlandı.

## 4. İşbirliği ve Paylaşım
- [x] Panoya başka kullanıcıları davet etme işleminde artık E-Posta adresinin yanında Kullanıcı Adı girerek de arama desteklendi.
- [x] Bir kartın içerisine panoya üye olan kişilerden sorumlular (assignees) atanabilecek.
- [x] Kartı dışarıyla (`SharePlus` veya Deep Link ile) link olarak paylaşma butonu eklenecek.

## 5. Arayüz (UI/UX) ve Erişilebilirlik
- [x] Listeler alt alta dizilecek. Liste açıldığında, içerisindeki kartlar kütüphane raflarındaki kitaplar gibi yan yana (GridView / Wrap kullanılarak) dizilecek.
- [x] Görme engelliler için optimize edilmiş; tüm taşıma, check etme, listeyi açma gibi işlemler SemanticsService ile desteklenip %100 erişilebilir hale getirilecek.
- [x] Hem mobil arayüz şıklığı sağlanacak, hem de tablet/büyük ekranlar için duyarlı (Responsive) bir yapı gözetilecek.
