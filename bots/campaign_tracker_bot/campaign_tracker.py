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

    def save_campaign(self, source_id, data):
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
        except Exception as e:
            print(f"Kayıt sırasında hata: {e}")

# --- Senin Sağladığın Scraping Mantığı ---
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
                    print(f"  [HATA] Güncelleme başarısız ({r.status_code}): {r.text}")
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

def liste_sayfasindan_linkleri_al(kategori_url):
    print(f"[*] Kategori sayfası taranıyor (Selenium ile): {kategori_url}")
    
    # Sunucuda arayüzsüz (headless) çalışması için tarayıcı ayarları
    chrome_options = Options()
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.add_argument("--disable-gpu")
    chrome_options.add_argument("--window-size=1920,1080")
    
    # [KRİTİK DÜZELTME] -> UBUNTU 24.04 SNAP DESTEĞİ
    driver = None
    
    # 1. Deneme: Ubuntu 24.04 ve üstü SNAP Kurulumu yolu
    try:
        chrome_options.binary_location = '/snap/bin/chromium'
        service = Service('/snap/bin/chromium.chromedriver')
        driver = webdriver.Chrome(service=service, options=chrome_options)
    except Exception as e_snap:
        # 2. Deneme: Eski tip APT kurulumu (veya Debian)
        try:
            chrome_options.binary_location = '/usr/bin/chromium-browser'
            service = Service('/usr/bin/chromedriver')
            driver = webdriver.Chrome(service=service, options=chrome_options)
        except Exception as e_apt:
            # 3. Deneme: Orijinal Webdriver Manager (Her şey başarısız olursa)
            try:
                chrome_options.binary_location = '' # Kendi bulsun
                driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
            except Exception as e_wdm:
                print(f"  [HATA] Tarayıcı başlatılamadı.\n  Snap Hatası -> {e_snap}\n  Apt Hatası -> {e_apt}\n  İndirilen WDM Hatası -> {e_wdm}")
                return []
    
    try:
        driver.get(kategori_url)
        
        # Sayfayı en aşağıya kadar kaydırma döngüsü (Tüm JS verileri yüklenene kadar)
        last_height = driver.execute_script("return document.body.scrollHeight")
        while True:
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(2) # JS'nin yeni kampanyaları yüklemesi için mola
            
            new_height = driver.execute_script("return document.body.scrollHeight")
            if new_height == last_height:
                # "Daha Fazla" butonu varsa tıklamayı dene
                try:
                    button = driver.find_element("xpath", "//button[contains(text(), 'Daha Fazla')]")
                    driver.execute_script("arguments[0].click();", button)
                    time.sleep(2)
                    new_height = driver.execute_script("return document.body.scrollHeight")
                    if new_height == last_height: break
                except:
                    break # Daha fazla kayacak yer kalmadıysa döngüyü kır
            last_height = new_height
            
        # JS ile tam yüklenmiş son HTML kaynağını çekiyoruz
        soup = BeautifulSoup(driver.page_source, 'html.parser')
        
        linkler = []
        for a_etiketi in soup.find_all('a', href=True):
            href = a_etiketi['href']
            if '/kampanyalar/' in href and not href.endswith('/kampanyalar'):
                full_url = urljoin("https://www.getkampania.com", href)
                clean_url = full_url.split('?')[0].rstrip('/')
                if clean_url not in linkler:
                    linkler.append(clean_url)
                    
        print(f"  [BİLGİ] Selenium ile toplam {len(linkler)} adet kampanya linki toplandı.")
        return linkler
        
    except Exception as e:
        print(f"[-] Liste çekilirken hata: {e}")
        return []
    finally:
        driver.quit()

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
            print(f"\nKaynak taranıyor: {src['name']}")
            links = liste_sayfasindan_linkleri_al(src['url'])
            for link in links:
                data = scraping_to_dict(link)
                if data:
                    bot_api.save_campaign(src['id'], data)
                time.sleep(1) # Siteyi yormamak için
        
        print(f"\n[{time.strftime('%H:%M:%S')}] --- Döngü bitti. 1 saat bekleniyor... ---")
        time.sleep(3600)

if __name__ == "__main__":
    run_bot()
