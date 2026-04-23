import os
import sys
import subprocess

def list_bots():
    print("\n--- Blind Social Bot Yönetim Sistemi ---")
    bots = [
        {"id": 1, "name": "Kampanya Takip Botu (Genel)", "path": "campaign_tracker_bot", "main": "campaign_tracker.py"},
    ]
    
    for bot in bots:
        print(f"{bot['id']}. {bot['name']}")
    return bots

def manage_bot(bot):
    while True:
        print(f"\n--- {bot['name']} Yönetimi ---")
        print("1. Botu Çalıştır (Anlık)")
        print("2. Bot Klasörüne Git (Bilgi)")
        print("3. Logları Görüntüle (Simüle)")
        print("0. Geri Dön")
        
        choice = input("\nSeçiminiz: ")
        if choice == '1':
            bot_path = os.path.join(os.getcwd(), bot['path'], bot['main'])
            print(f"Bot başlatılıyor: {bot_path}")
            try:
                # Botu bağımsız bir işlem olarak başlat
                subprocess.run([sys.executable, bot_path], check=True)
            except Exception as e:
                print(f"Hata: {e}")
        elif choice == '2':
            print(f"Konum: {os.path.join(os.getcwd(), bot['path'])}")
        elif choice == '0':
            break

if __name__ == "__main__":
    while True:
        available_bots = list_bots()
        print("0. Çıkış")
        
        try:
            choice = int(input("\nYönetmek istediğiniz botun numarasını seçin: "))
            if choice == 0:
                print("Kapatılıyor...")
                break
            
            selected_bot = next((b for b in available_bots if b['id'] == choice), None)
            if selected_bot:
                manage_bot(selected_bot)
            else:
                print("Geçersiz bot numarası.")
        except ValueError:
            print("Lütfen bir sayı girin.")
