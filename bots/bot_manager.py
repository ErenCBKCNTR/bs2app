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
    """Terminalde 'bot' komutunun çalışması için alias ekler."""
    script_path = os.path.abspath(__file__)
    home = os.path.expanduser("~")
    bashrc_path = os.path.join(home, ".bashrc")
    alias_line = f"alias bot='python3 {script_path}'\n"
    
    try:
        if os.path.exists(bashrc_path):
            with open(bashrc_path, 'r') as f:
                content = f.read()
            
            if alias_line not in content:
                print("\n[+] 'bot' kısayolu sisteminize ekleniyor...")
                with open(bashrc_path, 'a') as f:
                    f.write(f"\n# Blind Social Bot Manager Alias\n{alias_line}")
                print("[!] Kısayol eklendi. Aktif olması için: 'source ~/.bashrc'")
    except Exception as e:
        print(f"Kısayol eklenirken hata oluştu: {e}")

def update_bot():
    """GitHub'dan güncel dosyaları çeker ve temiz kurulum yapar."""
    print(f"\n[+] Sistem güncelleniyor (Dizin: {PROJECT_ROOT})...")
    try:
        # Git komutlarını ana dizinde (PROJECT_ROOT) çalıştır
        subprocess.run(["git", "fetch", "--all"], check=True, cwd=PROJECT_ROOT)
        subprocess.run(["git", "reset", "--hard", "origin/main"], check=True, cwd=PROJECT_ROOT)
        
        print("\n[✓] Güncelleme başarılı! Ekran temizleniyor...")
        time.sleep(1)
        os.system('clear')
        os.execv(sys.executable, ['python3'] + sys.argv)
    except Exception as e:
        print(f"Güncelleme sırasında hata oluştu: {e}")

def list_bots():
    print("\n--- Blind Social Bot Yönetim Sistemi ---")
    # Yollar PROJECT_ROOT'a göre göreceli
    bots = [
        {"id": 1, "name": "Kampanya Takip Botu (Genel)", "path": "bots/campaign_tracker_bot", "main": "campaign_tracker.py"},
    ]
    
    for bot in bots:
        print(f"{bot['id']}. {bot['name']}")
    return bots

def manage_bot(bot):
    while True:
        print(f"\n--- {bot['name']} Yönetimi ---")
        print("1. Botu Çalıştır (Anlık)")
        print("2. Bot Klasörüne Git (Bilgi)")
        print("0. Geri Dön")
        
        choice = input("\nSeçiminiz: ")
        if choice == '1':
            bot_path = os.path.join(PROJECT_ROOT, bot['path'], bot['main'])
            print(f"Bot başlatılıyor: {bot_path}")
            try:
                subprocess.run([sys.executable, bot_path], check=True)
            except Exception as e:
                print(f"Hata: {e}")
        elif choice == '2':
            print(f"Konum: {os.path.join(PROJECT_ROOT, bot['path'])}")
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
