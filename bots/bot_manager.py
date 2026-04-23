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
    """Terminalde 'blind' komutunun çalışması için alias ekler."""
    script_path = os.path.abspath(__file__)
    home = os.path.expanduser("~")
    bashrc_path = os.path.join(home, ".bashrc")
    
    # Yeni özel alias
    alias_blind = f"alias blind='python3 {script_path}'\n"
    
    try:
        if os.path.exists(bashrc_path):
            with open(bashrc_path, 'r') as f:
                lines = f.readlines()
            
            # Eski aliasları ve mevcut blind alias'ını temizle/kontrol et
            new_lines = []
            for line in lines:
                if "alias bot=" not in line and "alias bots=" not in line and "alias blind=" not in line:
                    new_lines.append(line)
            
            # Yeni alias'ı ekle
            new_lines.append(f"\n# Blind Social Bot Manager Alias\n{alias_blind}")
            
            with open(bashrc_path, 'w') as f:
                f.writelines(new_lines)
            
            print("\n[+] 'blind' kısayolu sisteminize tanımlandı.")
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

def install_dependencies(req_file):
    """Bağımlılıkları pip üzerinden kurar, pip yoksa önce onu kurmaya çalışır."""
    try:
        print("[+] Bağımlılıklar kontrol ediliyor...")
        # Önce pip var mı kontrol et
        check_pip = subprocess.run([sys.executable, "-m", "pip", "--version"], capture_output=True)
        
        if check_pip.returncode != 0:
            print("[!] 'pip' bulunamadı. Sunucunuza kurulmaya çalışılıyor...")
            # Sunucu root olduğu için apt-get ile kurmayı dene
            subprocess.run(["apt-get", "update"], check=False)
            subprocess.run(["apt-get", "install", "-y", "python3-pip"], check=False)
            print("[✓] 'pip' başarıyla kuruldu.")

        print("[+] Python kütüphaneleri kuruluyor...")
        # Şimdi kütüphaneleri kur
        subprocess.run([sys.executable, "-m", "pip", "install", "--ignore-installed", "--break-system-packages", "-r", req_file], check=True)
        
        print("[+] Playwright Tarayıcı Altyapısı Kuruluyor (Snap / Root kısıtlamalarından bağımsız)...")
        subprocess.run([sys.executable, "-m", "playwright", "install", "chromium", "--with-deps"], check=False)
        return True
    except Exception as e:
        print(f"\n[X] Bağımlılıklar kurulamadı: {e}")
        print("[!] Lütfen manuel olarak şu komutu terminale yazın: apt install python3-pip")
        return False

def manage_bot(bot):
    while True:
        print(f"\n--- {bot['name']} Yönetimi ---")
        print("1. Botu Çalıştır (Anlık)")
        print("2. Bot Klasörüne Git (Bilgi)")
        print("3. Bağımlılıkları Kur (pip install)")
        print("4. Zamanlayıcı Ayarları (Cron Jobs)")
        print("0. Geri Dön")
        
        choice = input("\nSeçiminiz: ")
        if choice == '1':
            bot_dir = os.path.join(PROJECT_ROOT, bot['path'])
            req_file = os.path.join(bot_dir, "requirements.txt")
            bot_path = os.path.join(bot_dir, bot['main'])
            
            # Bağımlılıkları kurmayı dene
            if os.path.exists(req_file):
                if not install_dependencies(req_file):
                    # Kütüphaneler kurulamazsa devam etme
                    continue
            
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
                install_dependencies(req_file)
            else:
                print("requirements.txt bulunamadı.")
        elif choice == '4':
            bot_dir = os.path.join(PROJECT_ROOT, bot['path'])
            bot_path = os.path.join(bot_dir, bot['main'])
            
            print("\n--- Zamanlayıcı Ayarları ---")
            print("1. Günde 1 Kere (Gece 03:00)")
            print("2. Günde 2 Kere (Gece 00:00 ve Öğlen 12:00)")
            print("3. Günde 3 Kere (00:00, 12:00, 18:00)")
            print("4. Günde 4 Kere (00:00, 06:00, 12:00, 20:00)")
            print("5. Zamanlayıcıyı Kapat (İptal)")
            print("0. İptal")
            
            cron_choice = input("Seçiminiz: ")
            
            schedule = ""
            if cron_choice == '1':
                schedule = "0 3 * * *"
            elif cron_choice == '2':
                schedule = "0 0,12 * * *"
            elif cron_choice == '3':
                schedule = "0 0,12,18 * * *"
            elif cron_choice == '4':
                schedule = "0 0,6,12,20 * * *"
            elif cron_choice == '5':
                schedule = "REMOVE"
            else:
                continue
                
            try:
                # Mevcut crontab'i oku
                current_cron = subprocess.run(['crontab', '-l'], capture_output=True, text=True).stdout
                
                # Bu botla ilgili eski satırları temizle
                new_cron_lines = []
                for line in current_cron.splitlines():
                    if bot_path not in line: # Bot scripti geçmeyenleri koru
                        new_cron_lines.append(line)
                
                # Yeni komutu oluştur ve ekle
                if schedule != "REMOVE":
                    cron_cmd = f"{schedule} {sys.executable} {bot_path} >> {os.path.join(bot_dir, 'cron_log.txt')} 2>&1"
                    new_cron_lines.append(cron_cmd)
                    
                final_cron = "\n".join(new_cron_lines) + "\n"
                
                # Yeni yapılandırmayı bash process üzerinden pipe'la crontab'a yaz
                process = subprocess.Popen(['crontab', '-'], stdin=subprocess.PIPE, text=True)
                process.communicate(final_cron)
                
                print(f"\n[✓] ZAMANLAYICI AKTİF! Sistem başarıyla güncellendi.")
                if schedule != "REMOVE":
                    print(f"Çalışma düzeni: {schedule}")
                else:
                    print("Zamanlayıcı iptal edildi.")
                
            except Exception as e:
                print(f"Crontab ayarlanırken bir hata oluştu: {e}")
                print("Lütfen sunucuda 'cron' servisinin çalıştığından emin olun.")

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
