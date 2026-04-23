import os
import sys
import subprocess
import time

REPO_URL = "https://github.com/ErenCBKCNTR/bs2app"

# Scriptin bulunduğu klasörden bağımsız olarak projenin ana dizinini bulur
# __file__: /root/bs2app/bots/bot_manager.py
# SCRIPT_DIR: /root/bs2app/bots
# PROJECT_ROOT: /root/bs2app
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

def check_and_add_alias():
    """Terminalde 'bot' veya 'bots' komutunun çalışması için alias ekler."""
    script_path = os.path.abspath(__file__)
    home = os.path.expanduser("~")
    bashrc_path = os.path.join(home, ".bashrc")
    
    # Hem 'bot' hem de 'bots' için alias tanımlıyoruz
    alias_bot = f"alias bot='python3 {script_path}'\n"
    alias_bots = f"alias bots='python3 {script_path}'\n"
    
    try:
        if os.path.exists(bashrc_path):
            with open(bashrc_path, 'r') as f:
                content = f.read()
            
            changes_made = False
            with open(bashrc_path, 'a') as f:
                if alias_bot not in content:
                    f.write(f"\n# Blind Social Bot Manager Alias\n{alias_bot}")
                    changes_made = True
                if alias_bots not in content:
                    f.write(alias_bots)
                    changes_made = True
            
            if changes_made:
                print("\n[+] 'bot' ve 'bots' kısayolları sisteminize eklendi.")
                print("[!] Aktif olması için: 'source ~/.bashrc' yazın.")
    except Exception as e:
        print(f"Kısayol eklenirken hata oluştu: {e}")

def list_bots():
    """Yönetilebilir botları listeler."""
    print("\n--- Blind Social Bot Yönetim Sistemi ---")
    bots = [
        {"id": 1, "name": "Kampanya Takip Botu (Genel)", "path": "bots/campaign_tracker_bot", "main": "campaign_tracker.py"},
    ]
    for bot in bots:
        print(f"{bot['id']}. {bot['name']}")
    return bots

def update_bot():
    """Kullanıcının yöntemiyle (curl/tar) eski dosyaları silip temiz güncelleme yapar."""
    print(f"\n[+] Sistem temizleniyor ve güncelleniyor (Konum: {PROJECT_ROOT})...")
    
    parent_dir = os.path.dirname(PROJECT_ROOT)
    dir_name = os.path.basename(PROJECT_ROOT) # bs2app
    archive_url = f"{REPO_URL}/archive/refs/heads/main.tar.gz"
    
    # Hafıza özelliğini korumak için config dosyasını yedekleyelim
    config_rel_path = "bots/campaign_tracker_bot/secret_config.json"
    config_full_path = os.path.join(PROJECT_ROOT, config_rel_path)
    backup_data = None
    
    if os.path.exists(config_full_path):
        try:
            with open(config_full_path, 'r') as f:
                backup_data = f.read()
            print("[i] Giriş bilgileriniz yedeklendi.")
        except:
            pass

    try:
        # Senin kullandığın komut mantığı: mkdir -p bs2app && curl ... | tar ...
        # Mevcut klasörü sil ve sıfır klasöre tar et
        print("[!] Eski sürüm siliniyor ve GitHub'dan en güncel sürüm indiriliyor...")
        
        update_cmd = (
            f"cd {parent_dir} && "
            f"rm -rf {dir_name} && "
            f"mkdir -p {dir_name} && "
            f"curl -L {archive_url} | tar -xz -C {dir_name} --strip-components=1"
        )
        
        subprocess.run(update_cmd, shell=True, check=True)
        
        # Yediği geri yükle
        if backup_data:
            new_config_path = os.path.join(PROJECT_ROOT, config_rel_path)
            os.makedirs(os.path.dirname(new_config_path), exist_ok=True)
            with open(new_config_path, 'w') as f:
                f.write(backup_data)
            print("[i] Giriş bilgileriniz otomatik olarak geri yüklendi.")

        print("\n[✓] Temiz güncelleme başarılı! Ekran temizleniyor...")
        time.sleep(1)
        os.system('clear')
        # Scripti yeniden başlat
        os.execv(sys.executable, ['python3'] + sys.argv)
    except Exception as e:
        print(f"Güncelleme hatası: {e}")
        print("İpucu: Sunucuda curl ve tar kurulu olduğundan emin olun.")

def manage_bot(bot):
    while True:
        print(f"\n--- {bot['name']} Yönetimi ---")
        print("1. Botu Çalıştır (Anlık)")
        print("2. Bot Klasörüne Git (Bilgi)")
        print("3. Bağımlılıkları Kur (pip install)")
        print("0. Geri Dön")
        
        choice = input("\nSeçiminiz: ")
        if choice == '1':
            bot_dir = os.path.join(PROJECT_ROOT, bot['path'])
            req_file = os.path.join(bot_dir, "requirements.txt")
            bot_path = os.path.join(bot_dir, bot['main'])
            
            # Botu çalıştırmadan önce bağımlılıkları kontrol et/kur
            if os.path.exists(req_file):
                print("[+] Bağımlılıklar kontrol ediliyor...")
                subprocess.run([sys.executable, "-m", "pip", "install", "-r", req_file], check=True)
            
            print(f"Bot başlatılıyor: {bot_path}")
            try:
                subprocess.run([sys.executable, bot_path], check=True)
            except Exception as e:
                print(f"Hata: {e}")
        elif choice == '2':
            print(f"Konum: {os.path.join(PROJECT_ROOT, bot['path'])}")
        elif choice == '3':
            req_file = os.path.join(PROJECT_ROOT, bot['path'], "requirements.txt")
            if os.path.exists(req_file):
                print("[+] Kuruluyor...")
                subprocess.run([sys.executable, "-m", "pip", "install", "-r", req_file])
            else:
                print("requirements.txt bulunamadı.")
        elif choice == '0':
            break

if __name__ == "__main__":
    check_and_add_alias()
    while True:
        available_bots = list_bots()
        print("9. Bot Sistemini Güncelle (GitHub)")
        print("0. Çıkış")
        
        try:
            choice = input("\nSeçiminiz: ")
            if choice == '0':
                break
            elif choice == '9':
                update_bot()
            else:
                choice_int = int(choice)
                selected_bot = next((b for b in available_bots if b['id'] == choice_int), None)
                if selected_bot:
                    manage_bot(selected_bot)
                else:
                    print("Geçersiz bot numarası.")
        except ValueError:
            print("Lütfen bir sayı girin.")
