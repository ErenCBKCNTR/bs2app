import os
import sys

def list_bots():
    print("\n--- Blind Social Bot Yönetim Sistemi ---")
    # Gelecekte bots/ klasörü altındaki klasörleri tarayacak şekilde geliştirilecek
    bots = [
        {"id": 1, "name": "Kampanya Takip Botu", "path": "campaign_tracker_bot"},
    ]
    
    for bot in bots:
        print(f"{bot['id']}. {bot['name']}")
    return bots

def manage_bot(bot_id):
    if bot_id == 1:
        print("\n--- Kampanya Takip Botu Yönetimi ---")
        print("1. Botu Başlat")
        print("2. Botu Durdur")
        print("3. Logları Görüntüle")
        print("0. Geri Dön")
        
        choice = input("\nSeçiminiz: ")
        if choice == '1':
            print("Kampanya Takip Botu başlatılıyor...")
            # subprocess.Popen ile bot scripti çalıştırılacak
        elif choice == '2':
            print("Kampanya Takip Botu durduruluyor...")
        elif choice == '3':
            print("Son loglar yükleniyor...")
    else:
        print("Geçersiz bot ID.")

if __name__ == "__main__":
    while True:
        available_bots = list_bots()
        print("0. Çıkış")
        
        try:
            choice = int(input("\nYönetmek istediğiniz botun numarasını seçin: "))
            if choice == 0:
                print("Kapatılıyor...")
                break
            manage_bot(choice)
        except ValueError:
            print("Lütfen bir sayı girin.")
