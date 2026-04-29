import 'package:flutter/material.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sürüm Notları'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            isLatest: true,
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
