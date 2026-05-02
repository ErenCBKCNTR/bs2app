import 'package:flutter/material.dart';
import '../../../../features/admin/data/services/admin_service.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AdminService().isAdmin()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erişim Engellendi')),
        body: const Center(child: Text('Bu sayfayı görüntüleme yetkiniz yok.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sürüm Notları'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildVersionSection(
            version: '1.7.7',
            date: '2 Mayıs 2026',
            changes: [
              'Hata Giderme: Web tarayıcılarında sesli ortamlara bağlanırken "minified" olarak görünen hata tespit edilip, daha güvenli bir bağlantı mekanizmasıyla değiştirildi. Olası mikrofon erişim reddinde odaya dinleyici olarak katılma izni eklendi.',
              'Hata Giderme: Mesaj gönderirken klavyenin zorla kapatılması sebebiyle ekranda arta kalan "yarım sayfa" sorunu klavye doğal davranışına bırakılarak çözüldü.',
              'İyileştirme: Canlı sesli iletişim için detaylı hata analizi alt yapısı genişletildi.'
            ],
            isLatest: true,
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.7.6',
            date: '2 Mayıs 2026',
            changes: [
              'Hata Giderme: Web üzerinden sesli mesaj gönderiminde yaşanan "0 saniye" sorunu giderildi.',
              'Hata Giderme: Web ortamında klavye kapatılınca ekranın altında oluşan beyaz kutu hatası çözüldü.',
              'İyileştirme: Web tarafındaki gereksiz emoji klavyesi uyarıları kaldırılarak arayüz sadeleştirildi.',
              'İyileştirme: Web tarayıcılarında sesli ortamlara bağlanırken yaşanan gecikmeler ve bağlantı engelleri yeniden yapılandırıldı.'
            ],
            isLatest: false,
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.7.5',
            date: '30 Nisan 2026',
            changes: [
              'Yeni: Görev panoları oluştururken kullanabileceğiniz hazır şablonlar (Yazılım Geliştirme, Proje Yönetimi vb.) eklendi.',
              'Yeni: Görev içine metin ve doğrudan sesli mesaj (mikrofon) bırakabileceğiniz yorumlar bölümü eklendi.',
              'Yeni: Tüm görevlerinizin tamamlanma veya bekleme durumunu istatistikleriyle görebileceğiniz "Görev Özeti ve Geçmişi" sayfası eklendi.',
              'Hata Giderme: Bazı şablonlarla pano oluşturulurken ortaya çıkan veritabanı "liste sırası" kaydetme hatası giderildi.',
            ],
            isLatest: false,
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.7.4',
            date: '30 Nisan 2026',
            changes: [
              'Yeni: Görev silme ve bağlantı adresi (URL) ekleme özellikleri getirildi.',
              'Yeni: Görevlere eklenen URL veya site bağlantılarının site başlıkları ekran okuyucu uyumlu bir şekilde otomatik çözümlenerek daha temiz okunması sağlandı.',
              'Yeni: URL bağlantılarını kopyalama ve silme seçenekleri işlemler menüsüne yerleştirildi.',
              'Yeni: Sürüm bilgisi (Changelog) sayfası gizliliği artırılarak standart kullanıcıların erişimine kapatıldı.',
              'İyileştirme: Görevin oluşturulma ekranında atanmış hedef bitiş tarihi (kalan gün) anonsları ve okunabilir tarih bildirimleri etkinleştirildi.',
            ],
            isLatest: false,
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.7.3',
            date: '30 Nisan 2026',
            changes: [
              'Yeni: Görev kronometresi tamamen yenilendi. Artık tıpkı sesli notlar gibi kronometre ile çalışılan tüm sürelerinizi tarih/saat belirtecek şekilde liste olarak görebilir ve silebilirsiniz.',
              'İyileştirme: Sesli not kaydetme, silme ve kronometre başlatıp durdurma işlemlerine ekran okuyucular için başarılı/başarısız bildirim sesli anonsları eklendi.',
              'İyileştirme: Kontrol listesinde dolaşırken ekran okuyucunun düzenleme seçenekleri bulunduğunu belirtmesi için anons sistemi iyileştirildi.',
            ],
          ),
          _buildVersionSection(
            version: '1.7.2',
            date: '30 Nisan 2026',
            changes: [
              'Yeni: Görevleri paylaşırken salt URL yerine görevin açıklaması, durumu, etiketleri, sorumluları ve geçirdiği zaman gibi tüm detaylarını içeren, ekran okuyucu uyumlu düz metin ile paylaşma özelliği açıldı.',
              'Yeni: Görev içerisindeki ses kayıtları artık duraklatılabiliyor ve kayıt aşamasında anında iptal edilebiliyor.',
              'İyileştirme: Ses kayıtlarını silme özelliği kısayolu olarak ekran okuyucuların eylem menüsüne eklendi.',
              'Yeni: Pano detay sayfasına "Bağlı Kullanıcılar" ekranı eklendi. Panodaki üyeleri, yetkilerini ve pano sahibini buradan yönetebilir veya görebilirsiniz.',
              'Yeni: Pano yöneticisi artık kullanıcılara sadece panoyu görüntüleme veya düzenleme yetkisi verebilecek.',
              'İyileştirme: Görev detaylarındaki sorumlular kısmında artık sadece sayı değil, atanan kullanıcıların adları açıkça yazıyor.',
              'İyileştirme: Panoyu silme ve düzenleme seçenekleri sadece pano sahiplerinde görünecek şekilde değiştirildi.',
              'İyileştirme: Kullanıcı listeleme ve yetki yönetimi tamamen ekran okuyucu uyumlu hale getirildi.',
            ],
            isLatest: true,
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.7.1',
            date: '30 Nisan 2026',
            changes: [
              'Yeni: Görevler için Sesli Notlar (Voice Notes) özelliği eklendi.',
              'Yeni: Görevlere başlangıç ve bitiş tarihi ekleme özelliği getirildi.',
              'İyileştirme: Görevlerde harcanan süre artık otomatik hesaplanıyor ve sesli olarak okunuyor.',
              'İyileştirme: Kontrol listesi tamamlanma oranları, ekran okuyucu uyumlu hale getirildi.',
              'Hata Düzeltmesi: Kontrol listesi eklerken yaşanan bazı hatalar giderildi.',
            ],
            isLatest: false,
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.7.0',
            date: '29 Nisan 2026',
            changes: [
              'Yeni: Ekiplerinizle uyum içinde çalışabileceğiniz, Trello benzeri gelişmiş Görev Panosu (Task Board) eklendi.',
              'Yeni: Görev listelerine sürükle-bırak tadında "Taşıma", "Başa Tutturma (Pin)" ve "Daraltma" seçenekleri eklendi.',
              'Yeni: Kartların içine adım adım ilerleyebileceğiniz kontrol listeleri (Checklist) oluşturabilirsiniz. Tamamlanma oranları ekran okuyucular tarafından anlık olarak söylenir.',
              'Yeni: Kartlara istediğiniz renkte etiketler ekleyerek kategorize edebilir, bu etiketlerle panoda arama yapabilirsiniz.',
              'Yeni: Görevleri diğer üyelere atayabilir veya sosyal medyada tek dokunuşla paylaşabilirsiniz.',
              'İyileştirme: Görev Panosu erişilebilirlik standartlarına uygun hale getirildi; tüm ikon, buton ve alanlar ekran okuyucu uyumludur.',
            ],
            isLatest: false,
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.6.4',
            date: '26 Nisan 2026',
            changes: [
              'Yeni: Sohbet sunucuları için dinamik kişi sayısı kapasite sistemi eklendi.',
              'İyileştirme: Ekran okuyucu kullanıcıları için sunucu listesinde kişi kapasitesi ("Şu anda sunucuda x kişi var" şeklinde) sesli dinleme deneyimine katıldı.',
              'İyileştirme: Sunuculardaki hayalet kullanıcı sorunu çözüldü! Kullanıcılar oyundan (veya uygulamadan) düştüğünde sunucuda boş yer açılması için otomatik temizleyici entegre edildi.',
              'Yeni: Sunucu kurucuları artık istenmeyen üyeleri sunucudan "Yasaklama (Ban)" işlemiyle kalıcı olarak uzaklaştırabilir.',
              'Yeni: Sunucu ayarlarında "Yasaklılar" listesi oluşturuldu, dilediğiniz kullanıcının engeli yine bu sekmeden kaldırılabilir.',
            ],
            isLatest: false,
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.6.3',
            date: '23 Nisan 2026',
            changes: [
              'İyileştirme: Kampanya listelerinde ekran okuyucu (TalkBack) deneyimi kusursuzlaştırıldı. Gereksiz kaynak okumaları temizlendi, tarihler daha anlaşılır hale getirildi.',
              'İyileştirme: Özel mesajlar menüsündeki "Arşivlenmiş" butonu "Arşivlenmiş Mesajlar" olarak düzeltildi.',
              'Yeni: Kampanya detay ekranına sağa sola kaydırarak hızlı geçiş desteği eklendi.',
              'Yeni: Kampanyaları sosyal medyada ve WhatsApp üzerinden paylaşabilmeniz için "Paylaş" butonu eklendi.',
              'İyileştirme: Kampanyalar uygulamaya özel önbellekleme mimarisine geçirilerek yükleme süreleri anında açılacak şekilde (veriden tasarrufu edilerek) hızlandırıldı.',
            ],
            isLatest: false,
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.4.0',
            date: '23 Nisan 2026',
            changes: [
              'Yeni: İstek, Öneri ve Şikayet Bildirimi özelliği eklendi. Artık görüşlerinizi doğrudan bize iletebilirsiniz.',
              'Yeni: Geri bildirimleriniz ile birlikte varsa sistemsel hatalar yöneticiye otomatik olarak iletilir.',
              'İyileştirme: Veri güvenliği ve veritabanı optimizasyonu için tüm mesaj alanlarına karakter sınırları getirildi.',
            ],
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.3.1',
            date: '23 Nisan 2026',
            changes: [
              'İyileştirme: Sunucu oluşturma arayüzü sadeleştirildi ve daha hızlı hale getirildi.',
              'İyileştirme: Sunucu oluştururken güvenlik ayarları bölümü eklendi.',
            ],
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.3.0',
            date: '23 Nisan 2026',
            changes: [
              'İyileştirme: Uygulama altyapısı ve sürüm yönetim sistemi güncellendi.',
              'İyileştirme: Sistem kararlılığını artıracak yeni geliştirme standartları devreye alındı.',
            ],
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.2.9',
            date: '23 Nisan 2026',
            changes: [
              'İyileştirme: Sürüm notları kullanıcı odaklı ve daha sade hale getirildi.',
              'İyileştirme: Teknik geliştirme detayları sürüm geçmişinden temizlendi.',
            ],
          ),
          _buildVersionSection(
            version: '1.2.8',
            date: '23 Nisan 2026',
            changes: [
              'İyileştirme: Veritabanı bağlantı kararlılığı ve genel sistem iyileştirmeleri yapıldı.',
            ],
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.2.4',
            date: '23 Nisan 2026',
            changes: [
              'İyileştirme: Gizlilik ayarları ayrı bir sayfa yapısına taşındı.',
              'İyileştirme: Ayarlar menüsü daha modüler ve düzenli hale getirildi.',
            ],
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.2.0',
            date: '23 Nisan 2026',
            changes: [
              'Yeni: Gizlilik ayarları menüsü eklendi.',
              'Yeni: Ekran görüntüsü ve kayıt koruması kullanıcı kontrolüne sunuldu.',
              'Yeni: Sürüm notları sayfası eklendi.',
              'İyileştirme: Uygulama performansı ve güvenliği artırıldı.',
            ],
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.1.0',
            date: '22 Nisan 2026',
            changes: [
              'Yeni: Gelişmiş güvenlik katmanları aktif edildi.',
              'Yeni: Ekran görüntüsü (screenshot) engelleme özelliği eklendi.',
              'Yeni: Cihaz güvenliği doğrulama sistemi devreye alındı.',
            ],
          ),
          const SizedBox(height: 24),
          _buildVersionSection(
            version: '1.0.0',
            date: '15 Nisan 2026',
            changes: [
              'Blind Social ilk sürümü yayınlandı!',
              'Erişilebilir sesli odalar ve sohbet özellikleri.',
              'Görme engelliler için optimize edilmiş arayüz.',
              'Google ile kolay giriş yapma özelliği.',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVersionSection({
    required String version,
    required String date,
    required List<String> changes,
    bool isLatest = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'v$version',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isLatest) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue),
                ),
                child: const Text(
                  'En Yeni',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Text(
              date,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...changes.map((change) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6.0),
                    child: Icon(Icons.circle, size: 6, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      change,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            )),
        const Divider(height: 32),
      ],
    );
  }
}
