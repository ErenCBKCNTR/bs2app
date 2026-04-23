import requests
import time
import getpass
import json
import os
import re
from bs4 import BeautifulSoup
from datetime import datetime

# PocketBase Bağlantı Ayarları
PB_URL = "http://127.0.0.1:8090" 
CONFIG_FILE = os.path.join(os.path.dirname(__file__), "secret_config.json")

class PocketBaseBot:
    def __init__(self):
        self.base_url = PB_URL
        self.admin_email, self.admin_password = self._load_config()
        self.token = self._authenticate()

    def _load_config(self):
        """Yerel dosyadan kayıtlı bilgileri yükler."""
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, 'r') as f:
                    data = json.load(f)
                    return data.get("email", ""), data.get("password", "")
            except:
                pass
        return "", ""

    def _save_config(self, email, password):
        """Başarılı giriş bilgilerini yerel dosyaya kaydeder."""
        try:
            with open(CONFIG_FILE, 'w') as f:
                json.dump({"email": email, "password": password}, f)
        except Exception as e:
            print(f"Bilgiler kaydedilemedi: {e}")

    def _authenticate(self):
        """Kimlik bilgilerini kontrol eder, gerekirse sorar ve kaydeder."""
        while True:
            if not self.admin_email or not self.admin_password:
                print("\n--- PocketBase Admin Girişi Gerekli ---")
                self.admin_email = input("Admin E-posta: ").strip()
                self.admin_password = getpass.getpass("Admin Şifre: ").strip()

            print(f"Giriş deneniyor ({self.admin_email})...")
            try:
                url = f"{self.base_url}/api/admins/auth-with-password"
                resp = requests.post(url, json={
                    "identity": self.admin_email,
                    "password": self.admin_password
                })
                
                if resp.status_code == 200:
                    print("Giriş başarılı! Token alındı.")
                    self._save_config(self.admin_email, self.admin_password)
                    return resp.json().get("token")
                else:
                    print("\n[!] Hata: Geçersiz e-posta veya şifre. Kayıtlı bilgiler temizleniyor...")
                    self.admin_email = "" 
                    self.admin_password = ""
                    if os.path.exists(CONFIG_FILE):
                        os.remove(CONFIG_FILE)
            except Exception as e:
                print(f"Bağlantı hatası: {e}")
                return None

    def get_brands_to_track(self):
        """Veritabanından takip edilecek URL'si olan markaları çeker."""
        headers = {"Authorization": f"Bearer {self.token}"}
        url = f"{self.base_url}/api/collections/brands/records"
        params = {"filter": 'campaign_url != ""'}
        
        resp = requests.get(url, headers=headers, params=params)
        if resp.status_code == 200:
            return resp.json().get("items", [])
        return []

    def save_campaign(self, brand_id, title, description, source_url, image_url=None, start_date=None, end_date=None):
        """Yeni bir kampanya kaydı oluşturur."""
        headers = {"Authorization": f"Bearer {self.token}"}
        
        # Başlık üzerinden kontrol (Duplicate önleme)
        check_url = f"{self.base_url}/api/collections/campaigns/records"
        params = {"filter": f'brand_id = "{brand_id}" && title = "{title}"'}
        check_resp = requests.get(check_url, headers=headers, params=params)
        if check_resp.status_code == 200 and len(check_resp.json().get("items", [])) > 0:
            return

        # Yeni kayıt ekle
        create_url = f"{self.base_url}/api/collections/campaigns/records"
        data = {
            "brand_id": brand_id,
            "title": title,
            "description": description,
            "source_url": source_url,
            "image_url": image_url or "",
            "start_date": start_date,
            "end_date": end_date,
            "is_active": True
        }
        requests.post(create_url, headers=headers, json=data)
        print(f"Yeni kampanya eklendi: {title}")

def parse_turkish_date(date_str):
    """Türkçe ay içeren tarih dizisini PocketBase formatına (ISO) çevirir."""
    months = {
        'Oca': '01', 'Şub': '02', 'Mar': '03', 'Nis': '04', 'May': '05', 'Haz': '06',
        'Tem': '07', 'Ağu': '08', 'Eyl': '09', 'Eki': '10', 'Kas': '11', 'Ara': '12'
    }
    try:
        # Örnek: "1 Nis 2026"
        parts = date_str.split()
        if len(parts) >= 3:
            day = parts[0].zfill(2)
            month = months.get(parts[1][:3], '01')
            year = parts[2]
            return f"{year}-{month}-{day} 00:00:00"
    except:
        pass
    return None

def scrape_getkampania_details(url):
    """GetKampania sitesinin detay sayfasını derinlemesine analiz eder."""
    print(f"  --> Detaylar çekiliyor: {url}")
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'}
    try:
        resp = requests.get(url, headers=headers, timeout=15)
        soup = BeautifulSoup(resp.text, 'html.parser')
        
        # 1. Başlık
        title = soup.find('h1').get_text().strip() if soup.find('h1') else ""
        
        # 2. Tarihler (Kampanya Katılımı: 1 Nis 2026 - 30 Nis 2026)
        start_date, end_date = None, None
        date_section = soup.find(text=re.compile("Kampanya Katılımı:"))
        if date_section:
            parent = date_section.parent.get_text()
            dates = re.findall(r"\d+\s+[A-Za-zçğıöşü]+\s+\d+", parent)
            if len(dates) >= 2:
                start_date = parse_turkish_date(dates[0])
                end_date = parse_turkish_date(dates[1])

        # 3. Görsel
        img_tag = soup.find('img', {'alt': title}) or soup.find('main').find('img') if soup.find('main') else None
        image_url = img_tag['src'] if img_tag else ""
        if image_url.startswith('/'): image_url = "https://www.getkampania.com" + image_url

        # 4. Detaylı Açıklama (Koşullar, Katılım Şekli vb.)
        description = ""
        sections = [
            ("🎟️ Katılım Noktaları", "Katılım noktaları"),
            ("👥 Faydalanabilecek Müşteriler", "Faydalanabilecek müşteriler"),
            ("📝 Katılım Şekli", "Katılım şekli"),
            ("⚖️ Koşullar", "Koşullar"),
            ("📅 Kazancın Kullanımı", "Kazancın Kullanımı")
        ]
        
        for label, identifier in sections:
            sect = soup.find(text=re.compile(identifier))
            if sect:
                content = sect.parent.find_next().get_text().strip() if sect.parent.find_next() else ""
                if content:
                    description += f"{label}:\n{content}\n\n"

        # Markalar (Migros, A101 vb.)
        brands_sect = soup.find(text=re.compile("Kampanyaya dahil markalar"))
        if brands_sect:
            brands_list = brands_sect.parent.find_next('div').get_text(separator=', ').strip()
            description += f"🏪 Dahil Markalar: {brands_list}\n"

        return {
            "title": title,
            "description": description[:2000],
            "image_url": image_url,
            "start_date": start_date,
            "end_date": end_date
        }
    except Exception as e:
        print(f"Detay Scrape Hatası: {e}")
        return None

def scrape_generic(url):
    """Genel kazıma veya siteye özel derin kazıma stratejisini seçer."""
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'}
    try:
        resp = requests.get(url, headers=headers, timeout=15)
        soup = BeautifulSoup(resp.text, 'html.parser')
        found_data = []

        is_getkampania = "getkampania.com" in url

        if is_getkampania:
            # GetKampania Özel: Liste sayfasındaki tüm kampanya linklerini bul
            links = []
            for a in soup.find_all('a', href=re.compile(r'/kampanyalar/')):
                full_url = "https://www.getkampania.com" + a['href'] if a['href'].startswith('/') else a['href']
                if full_url not in links: links.append(full_url)
            
            for link in links[:15]: # Her taramada en yeni 15 kampanyaya bak
                details = scrape_getkampania_details(link)
                if details:
                    details["url"] = link
                    found_data.append(details)
                    time.sleep(2) # Siteyi yormamak ve engellenmemek için
        else:
            # Standart Genel Kazıma Mantığı
            for heading in soup.find_all(['h2', 'h3']):
                title = heading.get_text().strip()
                if len(title) < 10: continue
                container = heading.find_parent()
                desc_tag = heading.find_next('p')
                desc = desc_tag.get_text().strip() if desc_tag else "Detaylar için web sitesini ziyaret ediniz."
                img_tag = container.find('img', src=True) or heading.find_next('img', src=True)
                img_url = img_tag['src'] if img_tag else ""
                link_tag = container.find('a', href=True) or heading.find_next('a', href=True)
                href = link_tag['href'] if link_tag else url
                found_data.append({
                    "title": title,
                    "description": desc,
                    "url": href,
                    "image_url": img_url,
                    "start_date": None,
                    "end_date": None
                })
        return found_data
    except Exception as e:
        print(f"Scrape hatası ({url}): {e}")
        return []

def main():
    bot_api = PocketBaseBot()
    if not bot_api.token:
        print("Token alınamadı, bot durduruluyor.")
        return

    brands = bot_api.get_brands_to_track()
    print(f"{len(brands)} marka/kaynak için tarama başlatılıyor...")

    for brand in brands:
        print(f"\n--- [{brand['name']}] Taranıyor: {brand['campaign_url']} ---")
        campaigns = scrape_generic(brand['campaign_url'])
        
        for cp in campaigns:
            bot_api.save_campaign(
                brand['id'], 
                cp['title'], 
                cp['description'], 
                cp['url'], 
                image_url=cp.get('image_url'),
                start_date=cp.get('start_date'),
                end_date=cp.get('end_date')
            )
            time.sleep(1) 

if __name__ == "__main__":
    main()
