import json
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import os
import time
import re

# Pocketbase bağlantısı için gerekli bilgiler
PB_URL = "http://127.0.0.1:8090" 

class CampaignBotAPI:
    def __init__(self, pb_url):
        self.pb_url = pb_url
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }

    def get_sources_to_track(self):
        """Yönetici panelinden eklenen kaynakları (URL) çeker."""
        try:
            resp = requests.get(f"{self.pb_url}/api/collections/campaign_sources/records")
            if resp.status_code == 200:
                return resp.json().get('items', [])
        except Exception as e:
            print(f"Kaynaklar çekilirken hata: {e}")
        return []

    def save_campaign(self, source_id, data):
        """Botun bulduğu kampanyayı PocketBase'e kaydeder veya günceller."""
        try:
            # Mükerrer kaydı önlemek için URL kontrolü
            check_resp = requests.get(
                f"{self.pb_url}/api/collections/campaigns/records",
                params={"filter": f'original_url="{data["Kampanya_URL"]}"'}
            )
            existing = check_resp.json().get('items', []) if check_resp.status_code == 200 else []
            
            payload = {
                "source_id": source_id,
                "title": data["Baslik"],
                "image_url": data["Gorsel_URL"],
                "duration_text": data["Kampanya_Katilimi"],
                "usage_text": data["Kazancin_Kullanimi"],
                "details_json": data["Detaylar"],
                "brands_json": data["Markalar"],
                "conditions_json": data["Kosullar"],
                "original_url": data["Kampanya_URL"]
            }

            if existing:
                # Güncelle
                record_id = existing[0]['id']
                requests.patch(f"{self.pb_url}/api/collections/campaigns/records/{record_id}", json=payload)
                print(f"  [GÜNCELLENDİ] {data['Baslik']}")
            else:
                # Yeni oluştur
                requests.post(f"{self.pb_url}/api/collections/campaigns/records", json=payload)
                print(f"  [YENİ KAYIT] {data['Baslik']}")
                
        except Exception as e:
            print(f"Kayıt sırasında hata: {e}")

# --- Senin Sağladığın Scraping Mantığı (PocketBase Entegrasyonlu) ---

def liste_sayfasindan_linkleri_al(kategori_url):
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
    try:
        response = requests.get(kategori_url, headers=headers)
        response.encoding = 'utf-8'
        soup = BeautifulSoup(response.text, 'html.parser')
        linkler = []
        for a_etiketi in soup.find_all('a', href=True):
            href = a_etiketi['href']
            if href.startswith('/kampanyalar/'):
                full_url = urljoin("https://www.getkampania.com", href)
                if full_url not in linkler:
                    linkler.append(full_url)
        return linkler
    except Exception as e:
        print(f"Kategori hatası: {e}")
        return []

def scraping_to_dict(url):
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
    veri = {"Kampanya_URL": url, "Baslik": "", "Gorsel_URL": "", "Kampanya_Katilimi": "", "Kazancin_Kullanimi": "", "Detaylar": {}, "Markalar": [], "Kosullar": []}
    try:
        response = requests.get(url, headers=headers)
        response.encoding = 'utf-8'
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Görsel Çekimi
        og_image = soup.find('meta', property='og:image')
        if og_image: veri["Gorsel_URL"] = og_image.get('content', '')

        main_content = soup.find('main') or soup
        h1 = main_content.find('h1')
        if h1: veri["Baslik"] = h1.get_text(strip=True)

        tarihler = main_content.find_all('span', class_='text-neutral-500')
        for span in tarihler:
            parent_text = span.parent.get_text(separator=" ", strip=True)
            if "Kampanya Katılımı" in parent_text: veri["Kampanya_Katilimi"] = parent_text.replace("Kampanya Katılımı:", "").strip()
            elif "Kazancın Kullanımı" in parent_text: veri["Kazancin_Kullanimi"] = parent_text.replace("Kazancın Kullanımı:", "").strip()

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
                if veri["Kosullar"]: break
            except Exception: continue
            
        return veri
    except Exception as e:
        print(f"Detay hatası ({url}): {e}")
        return None

# --- Ana Döngü ---

def run_bot():
    bot_api = CampaignBotAPI(PB_URL)
    while True:
        print(f"\n[{time.strftime('%H:%M:%S')}] --- Bot Döngüsü Başladı ---")
        sources = bot_api.get_sources_to_track()
        
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
