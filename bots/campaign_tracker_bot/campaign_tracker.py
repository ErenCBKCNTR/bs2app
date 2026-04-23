import requests
import time
import getpass
import json
import os
from bs4 import BeautifulSoup

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

    def save_campaign(self, brand_id, title, description, source_url):
        """Yeni bir kampanya kaydı oluşturur."""
        # Önce bu başlıkta bir kampanya var mı kontrol et (Mükerrer kaydı önlemek için)
        headers = {"Authorization": f"Bearer {self.token}"}
        check_url = f"{self.base_url}/api/collections/campaigns/records"
        params = {"filter": f'brand_id = "{brand_id}" && title = "{title}"'}
        
        check_resp = requests.get(check_url, headers=headers, params=params)
        if check_resp.status_code == 200 and len(check_resp.json().get("items", [])) > 0:
            return # Zaten kayıtlı

        # Yeni kayıt ekle
        create_url = f"{self.base_url}/api/collections/campaigns/records"
        data = {
            "brand_id": brand_id,
            "title": title,
            "description": description,
            "source_url": source_url,
            "is_active": True
        }
        requests.post(create_url, headers=headers, json=data)
        print(f"Yeni kampanya eklendi: {title}")

def scrape_generic(url):
    """Genel bir web scraping mantığı uygular."""
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        resp = requests.get(url, headers=headers, timeout=15)
        soup = BeautifulSoup(resp.text, 'html.parser')
        
        # Basitleştirilmiş: Linkleri ve başlıkları topla
        found_data = []
        # Not: Burası site bazlı özelleştirilebilir veya LLM/regex tabanlı analiz edilebilir.
        # Şimdilik h3/h2 başlıklarını ve yakınındaki linkleri baz alan genel bir mantık:
        for heading in soup.find_all(['h2', 'h3']):
            title = heading.get_text().strip()
            if len(title) > 10: # Çok kısa başlıkları ele
                # En yakın linki bulmaya çalış
                link_tag = heading.find_parent().find('a', href=True) or heading.find_next('a', href=True)
                href = link_tag['href'] if link_tag else url
                full_link = f"{url.split('.com')[0]}.com{href}" if href.startswith('/') else href
                
                found_data.append({
                    "title": title,
                    "desc": "Kampanya detayları için web sitesini ziyaret ediniz.",
                    "url": full_link
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
    print(f"{len(brands)} marka için tarama başlatılıyor...")

    for brand in brands:
        brand_id = brand['id']
        brand_name = brand['name']
        track_url = brand['campaign_url']
        
        print(f"\n[{brand_name}] taranıyor: {track_url}")
        campaigns = scrape_generic(track_url)
        
        for cp in campaigns:
            bot_api.save_campaign(brand_id, cp['title'], cp['desc'], cp['url'])
            time.sleep(1) # Siteyi yormamak için

if __name__ == "__main__":
    main()
