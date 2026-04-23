import requests
from bs4 import BeautifulSoup
import time

# PocketBase Ayarları (Sunucu üzerinde çalışırken localhost veya iç IP kullanılabilir)
PB_URL = "http://localhost:8090" # Veya projenin PocketBase URL'si
AUTH_EMAIL = "admin@example.com"
AUTH_PASSWORD = "password"

def scrape_yapi_kredi():
    # Yapı Kredi resmi kampanya sayfası
    url = "https://www.yapikredi.com.tr/kampanyalar"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    print(f"[{time.ctime()}] Yapı Kredi kampanyaları taranıyor...")
    
    try:
        response = requests.get(url, headers=headers)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Site yapısına göre seçiciler (Temsili, Yapı Kredi'nin güncel DOM yapısına göre uyarlanmalıdır)
        # Genellikle kampanya listeleri belirli bir 'class' altındaki 'div'lerden oluşur.
        campaign_items = soup.find_all('div', class_='campaign-item') # Örnek Seçici
        
        campaigns = []
        for item in campaign_items:
            title = item.find('h3').text.strip() if item.find('h3') else ""
            desc = item.find('p').text.strip() if item.find('p') else ""
            link = item.find('a')['href'] if item.find('a') else ""
            
            if title:
                campaigns.append({
                    "title": title,
                    "description": desc,
                    "url": f"https://www.yapikredi.com.tr{link}" if link.startswith('/') else link
                })
        
        # Eğer yukarıdaki seçici boş dönerse (Site yapısı farklıysa) alternatif genel seçici
        if not campaigns:
             links = soup.find_all('a', href=True)
             for l in links:
                 if 'kampanya' in l['href'].lower() and len(l.text.strip()) > 10:
                     campaigns.append({
                         "title": l.text.strip(),
                         "description": "Detaylar için web sitesini ziyaret edin.",
                         "url": f"https://www.yapikredi.com.tr{l['href']}" if l['href'].startswith('/') else l['href']
                     })

        print(f"Başarıyla {len(campaigns)} kampanya taslağı bulundu.")
        return campaigns
    except Exception as e:
        print(f"Scraping Hatası: {e}")
        return []

def run_bot():
    results = scrape_yapi_kredi()
    for res in results[:5]:
        print(f"Bulunan: {res['title']}")
        # Burada PocketBase API'ye POST isteği atılarak veriler kaydedilecek.

if __name__ == "__main__":
    run_bot()
