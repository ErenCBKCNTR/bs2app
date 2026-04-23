import json
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import os
import time
import re
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager

# Pocketbase bağlantısı için gerekli bilgiler
PB_URL = "https://api.cabukcan.com"
CONFIG_FILE = "bot_config.json"

class CampaignBotAPI:
    def __init__(self, pb_url):
        self.pb_url = pb_url
        self.token = ""
        self.email = ""
        self.password = ""
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }

    def load_config(self):
        """Kaydedilmiş giriş bilgilerini yükler."""
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, 'r') as f:
                    config = json.load(f)
                    self.email = config.get('email', '')
                    self.password = config.get('password', '')
                    return True
            except: pass
        return False

    def save_config(self):
        """Giriş bilgilerini dosyaya kaydeder."""
        with open(CONFIG_FILE, 'w') as f:
            json.dump({'email': self.email, 'password': self.password}, f)

    def authenticate(self):
        """PocketBase'e giriş yapar. Bilgiler yoksa veya yanlışsa soru sorar."""
        # Önce dosyadan yüklemeyi dene
        self.load_config()

        while True:
            if not self.email or not self.password:
                print("\n--- PocketBase Giriş Bilgileri Gerekli ---")
                self.email = input("E-posta adresinizi girin: ").strip()
                self.password = input("Şifrenizi girin: ").strip()

            try:
                resp = requests.post(
                    f"{self.pb_url}/api/collections/users/auth-with-password",
                    json={"identity": self.email, "password": self.password}
                )
                if resp.status_code == 200:
                    self.token = resp.json().get('token', '')
                    self.headers["Authorization"] = f"Bearer {self.token}"
                    print(f"  [BAŞARILI] {self.email} olarak giriş yapıldı.")
                    self.save_config() # Başarılı girişi kaydet
                    return True
                else:
                    print(f"  [HATA] Giriş başarısız. Lütfen bilgileri kontrol edin.")
                    self.email = "" # Bilgileri sıfırla ki tekrar sorsun
                    self.password = ""
            except Exception as e:
                print(f"  [HATA] Bağlantı hatası: {e}")
                return False

    def get_sources_to_track(self):
        """Yönetici panelinden eklenen kaynakları (URL) çeker."""
        try:
            resp = requests.get(
                f"{self.pb_url}/api/collections/campaign_sources/records",
                headers=self.headers
            )
            if resp.status_code == 200:
                items = resp.json().get('items', [])
                print(f"  [BİLGİ] Veritabanından {len(items)} adet kaynak çekildi.")
                return items
            else:
                print(f"  [HATA] Kaynaklar çekilemedi: {resp.status_code}")
        except Exception as e:
            print(f"  [HATA] Kaynak çekme hatası: {e}")
        return []

    def save_campaign(self, source_id, source_category, data):
        """Botun bulduğu kampanyayı PocketBase'e kaydeder veya günceller."""
        try:
            # Mükerrer kaydı önlemek için URL kontrolü
            check_resp = requests.get(
                f"{self.pb_url}/api/collections/campaigns/records",
                params={"filter": f'original_url="{data["Kampanya_URL"]}"'},
                headers=self.headers
            )
            existing = check_resp.json().get('items', []) if check_resp.status_code == 200 else []
            
            payload = {
                "source_id": source_id,
                "category": source_category,
                "title": data["Baslik"],
                "image_url": data["Gorsel_URL"],
                "camp_start": data.get("Kampanya_Baslangic", ""),
                "camp_end": data.get("Kampanya_Bitis", ""),
                "usage_start": data.get("Kazanc_Baslangic", ""),
                "usage_end": data.get("Kazanc_Bitis", ""),
                "duration_text": data.get("Kampanya_Katilimi", ""),
                "usage_text": data.get("Kazancin_Kullanimi", ""),
                "details_json": data["Detaylar"],
                "brands_json": data["Markalar"],
                "conditions_json": data["Kosullar"],
                "actual_source_url": data.get("Kampanya_Detay_URL", ""),
                "original_url": data["Kampanya_URL"]
            }

            if existing:
                # Güncelle
                record_id = existing[0]['id']
                r = requests.patch(
                    f"{self.pb_url}/api/collections/campaigns/records/{record_id}", 
                    json=payload,
                    headers=self.headers
                )
                if r.status_code == 200:
                    print(f"  [GÜNCELLENDİ] {data['Baslik']}")
            else:
                # Yeni oluştur
                r = requests.post(
                    f"{self.pb_url}/api/collections/campaigns/records", 
                    json=payload,
                    headers=self.headers
                )
                if r.status_code == 200:
                    print(f"  [YENİ KAYIT] {data['Baslik']}")
                else:
                    print(f"  [HATA] Kayıt başarısız ({r.status_code}): {r.text}")
                
        except Exception as e:
            print(f"Kayıt sırasında hata: {e}")

# --- Senin Sağladığın Scraping Mantığı (Hassas Tarih Ayrıştırmalı) ---

from playwright.sync_api import sync_playwright

def liste_sayfasindan_linkleri_al(kategori_url):
    print(f"[*] Kategori sayfası taranıyor (Playwright ile): {kategori_url}")
    linkler = []
    
    try:
        with sync_playwright() as p:
            # Playwright'ın kendi izole tarayıcısını (chromium) başlatıyoruz
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            
            # Sayfaya git ve yüklenmesini bekle
            page.goto(kategori_url, wait_until="networkidle")
            
            # Sonsuz kaydırma simülasyonu
            last_height = page.evaluate("document.body.scrollHeight")
            while True:
                page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
                page.wait_for_timeout(2000) # JS'nin yeni içeriği yüklemesi için 2 sn
                
                new_height = page.evaluate("document.body.scrollHeight")
                if new_height == last_height:
                    # Daha Fazla butonu varsa bas
                    try:
                        # Butonu bul ve tıkla
                        if page.locator("button:has-text('Daha Fazla')").count() > 0:
                            page.locator("button:has-text('Daha Fazla')").click()
                            page.wait_for_timeout(2000)
                            new_height = page.evaluate("document.body.scrollHeight")
                            if new_height == last_height: break
                        else:
                            break
                    except Exception as e_btn:
                        break # Buton tıklandığında hata olursa döngüyü kır
                        
                last_height = new_height
            
            # Tam yüklenmiş HTML kaynağını çek ve BeautifulSoup'a ver
            html_content = page.content()
            soup = BeautifulSoup(html_content, 'html.parser')
            
            for a_etiketi in soup.find_all('a', href=True):
                href = a_etiketi['href']
                if '/kampanyalar/' in href and not href.endswith('/kampanyalar'):
                    full_url = urljoin("https://www.getkampania.com", href)
                    clean_url = full_url.split('?')[0].rstrip('/')
                    if clean_url not in linkler:
                        linkler.append(clean_url)
                        
            print(f"  [BİLGİ] Playwright ile toplam {len(linkler)} adet kampanya linki toplandı.")
            browser.close()
            return linkler
            
    except Exception as e:
        print(f"[-] Liste çekilirken hata: {e}")
        return []

def scraping_to_dict(url):
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
    veri = {
        "Kampanya_URL": url, "Baslik": "", "Gorsel_URL": "", 
        "Kampanya_Baslangic": "", "Kampanya_Bitis": "",
        "Kazanc_Baslangic": "", "Kazanc_Bitis": "",
        "Detaylar": {}, "Markalar": [], "Kosullar": []
    }
    try:
        response = requests.get(url, headers=headers)
        response.encoding = 'utf-8'
        soup = BeautifulSoup(response.text, 'html.parser')
        
        og_image = soup.find('meta', property='og:image')
        if og_image: veri["Gorsel_URL"] = og_image.get('content', '')

        main_content = soup.find('main') or soup
        h1 = main_content.find('h1')
        if h1: veri["Baslik"] = h1.get_text(strip=True)

        # Orijinal Kampanya Kaynak Linki (actual_source_url)
        for a in main_content.find_all('a', href=True):
            if "Web sayfasında görüntüle" in a.get_text(strip=True):
                veri["Kampanya_Detay_URL"] = a['href']
                break

        # Tarih Ayrıştırma (Split Mantığı)
        tarihler = main_content.find_all('span', class_='text-neutral-500')
        for span in tarihler:
            parent_text = span.parent.get_text(separator=" ", strip=True)
            
            if "Kampanya Katılımı" in parent_text:
                temiz_metin = parent_text.replace("Kampanya Katılımı:", "").strip()
                parcalar = temiz_metin.split("-")
                if len(parcalar) == 2:
                    veri["Kampanya_Baslangic"] = parcalar[0].strip()
                    veri["Kampanya_Bitis"] = parcalar[1].strip()
                else:
                    veri["Kampanya_Baslangic"] = temiz_metin

            elif "Kazancın Kullanımı" in parent_text:
                temiz_metin = parent_text.replace("Kazancın Kullanımı:", "").strip()
                parcalar = temiz_metin.split("-")
                if len(parcalar) == 2:
                    veri["Kazanc_Baslangic"] = parcalar[0].strip()
                    veri["Kazanc_Bitis"] = parcalar[1].strip()
                else:
                    veri["Kazanc_Baslangic"] = temiz_metin

        # Detaylar, Markalar ve Diğerleri
        for h3 in main_content.find_all('h3', class_=lambda c: c and 'font-semibold' in c):
            baslik = h3.get_text(strip=True)
            p_desc = h3.find_next_sibling('p')
            if p_desc: veri["Detaylar"][baslik] = p_desc.get_text(strip=True)

        markalar_h2 = main_content.find('h2', string=lambda t: t and "Kampanyaya dahil markalar" in t)
        if markalar_h2:
            markalar_div = markalar_h2.find_next_sibling('div')
            if markalar_div:
                for p in markalar_div.find_all('p'):
                    metin = p.get_text(strip=True)
                    if metin: veri["Markalar"].append(metin)

        for script in soup.find_all('script', type='application/ld+json'):
            try:
                js_data = json.loads(script.string)
                items = js_data if isinstance(js_data, list) else [js_data]
                for item in items:
                    if isinstance(item, dict) and 'disambiguatingDescription' in item:
                        kosullar_metni = item['disambiguatingDescription']
                        veri["Kosullar"] = [k.strip() for k in kosullar_metni.split(';') if k.strip()]
                        break
            except Exception: continue
            
        return veri
    except Exception as e:
        print(f"Detay hatası ({url}): {e}")
        return None

# --- Ana Döngü ---

def run_bot():
    bot_api = CampaignBotAPI(PB_URL)
    
    # Giriş yap (Authenticate)
    if not bot_api.authenticate():
        print("[KRİTİK] Veritabanı girişi başarısız! Bilgileri kontrol edin.")
        return

    while True:
        print(f"\n[{time.strftime('%H:%M:%S')}] --- Bot Döngüsü Başladı ---")
        sources = bot_api.get_sources_to_track()
        
        if not sources:
            print("  [UYARI] Taranacak kaynak bulunamadı. Lütfen yönetim panelinden 'Kaynaklar' ekleyin.")
        
        for src in sources:
            cat = src.get('category')
            if not cat: # PocketBase boş alanlar için "" dönebilir, bunu handle ediyoruz.
                cat = 'Diğer'
                
            print(f"\nKaynak taranıyor ({cat}): {src['name']}")
            links = liste_sayfasindan_linkleri_al(src['url'])
            for link in links:
                data = scraping_to_dict(link)
                if data:
                    bot_api.save_campaign(src['id'], cat, data)
                time.sleep(1) # Siteyi yormamak için
        
        print(f"\n[{time.strftime('%H:%M:%S')}] --- Döngü bitti. 1 saat bekleniyor... ---")
        time.sleep(3600)

if __name__ == "__main__":
    run_bot()
