# Arayüz ve Yerleşim Kuralları

## Temel Prensipler
- **Önce SafeArea:** Her sayfa (Screen) ve global bileşen, içeriğin sistem çubukları (durum çubuğu, navigasyon çubuğu, çentikler) tarafından engellenmesini önlemek için mutlaka bir `SafeArea` widget'ı ile sarmalanmalıdır.
- **Taşma Önleme:** Liste veya dinamik içerik barındıran tüm yerleşimler, farklı ekran boyutlarında `RenderFlex` taşma hatalarını önlemek için kaydırılabilir görünümler (`ListView`, `SingleChildScrollView`) kullanmalıdır.
- **Alt Sayfalar (Bottom Sheets):** Tüm modal alt sayfalar `useSafeArea: true` kullanmalı ve butonların tam görünür olmasını sağlamak için navigasyon çubuğu alanı için dahili dolguyu (`MediaQuery.of(context).padding.bottom` kullanarak) yönetmelidir.
- **Minimalist ve Simetrik Tasarım:** Tüm kullanıcı arayüzü bileşenleri (özellikle grup sesli sohbet odaları, modal diyaloglar veya kontrol panelleri) katı bir simetrik yerleşim yapısını korumalıdır. Simetrik buton yerleşimi, dengeli dolgu ve mükemmel hizalanmış kontroller tartışılamaz bir kuraldır.
- **Kimlik Görüntüleme Önceliği:** Tüm arayüz öğelerinde 'kullanıcı adlarını' (username) gerçek 'tam adlara' veya belirgin profil resimlerine her zaman tercih edin. Arayüz kesinlikle işlevsel, sade ve minimalist bir tasarım diline sahip olmalıdır.

## Erişilebilirlik (Ekran Okuyucular)
- Her etkileşimli öğe (`IconButton`, `InkWell`, `ElevatedButton`, vb.), "etiketsiz" olarak okunmasını önlemek için anlamlı bir `semanticsLabel` veya `tooltip` değerine sahip olmalıdır.
- **Çift Etiketleme Yasağı:** Etkileşimli öğelerin gereksiz veya birden fazla semantik düğüme sahip olmadığından emin olun. Bir butonu `Semantics` widget'ı ile sarmalıyorsanız, ana etiketten sonra "etiketsiz" (unlabeled) anonslarını önlemek için butonun dahili bileşenlerinde (İkonlar gibi) `ExcludeSemantics` kullanın veya butonun kendi semantik özelliklerini (örneğin `tooltip`) kullanın.
- Gereksiz açıklamalardan (örneğin "buton butonu") kesinlikle kaçınılmalıdır.
- Büyük metinler ve özel widget'lar, daha iyi navigasyon için uygun yerlerde `Semantics` widget başlıklarını kullanmalıdır.
- Görseller, görsel içeriğin açıklamasını sağlayan bir `semanticsLabel` değerine sahip olmalıdır.
