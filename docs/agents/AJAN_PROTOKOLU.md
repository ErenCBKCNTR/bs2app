# Yapay Zeka Ajanı İletişim Protokolü

## Zorunlu Kural: Kaynak Referansı Şeffaflığı
- **Okuma Doğrulaması:** Üretilen HER yanıt için, yapay zeka ajanı görev sırasında `docs/agents/` dizininden hangi markdown dosyalarının okunduğunu ve referans alındığını açıkça belirtmelidir.
- **Raporlama Formatı:** Ajan, dosya adlarını (örneğin: `Okunan Dosyalar: ARAYUZ_YERLESIM_KURALLARI.md, GELISTIRME_GUVENLIK.md`) nihai yanıtının başında veya sonunda net bir şekilde listelemelidir.
- **Doğrulama Amacı:** Bu, kullanıcının yapay zekanın belirlenen proje hafızasına ve modüler yönergelere uyduğundan emin olmasını sağlar.

## Dil ve Yerelleştirme Kuralı
- **Zorunlu Dil (Türkçe):** Bundan sonra oluşturulan tüm yeni kurallar, dökümanlar, hafıza dosyaları ve günlük kayıtları MUTLAKA Türkçe olarak yazılmalıdır. İngilizce dökümantasyon sadece teknik terimler için kullanılabilir.
- **Dosya İsimlendirme:** Yeni oluşturulan hafıza dosyalarının isimleri de Türkçe karakter içermeyen ancak Türkçe anlam taşıyan şekilde (örneğin: `YENI_KURAL.md`) seçilmelidir.

## Görev Başlatma
- **ZORUNLU GÖREV BAŞLATMA KONTROLÜ:** Yapay zeka ajanları, HER görevin başında `docs/agents/` dizinindeki ilgili dosyaları okumalıdır. Bu kural tartışılamazdır.
- Yeni bir şey oluşturmadan önce, `SISTEM_KATALOGU.md` dosyasında uygun bir bileşenin veya servisin zaten mevcut olup olmadığını kontrol edin.
- Veritabanıyla ilgili herhangi bir işlem yapmadan önce, tam tutarlılığı sağlamak için `pb_schema.json` dosyasını bir kez okuyun.
