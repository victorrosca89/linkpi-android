# LinkPi Android

Chat LAN peer-to-peer • Compatibil cu LinkPi Windows
Protocol identic: UDP 50506 (discovery) + TCP 50505 (mesaje/fișiere)

---

## Compilare APK — Pas cu Pas (GitHub Codespaces, GRATUIT)

### 1. Creează un repo nou pe GitHub
- Du-te pe https://github.com → New repository
- Nume: `linkpi-android` → Create repository

### 2. Urcă fișierele
- Click "uploading an existing file"
- Trage tot folderul `linkpi_flutter` (sau zip → extract)
- Commit changes

### 3. Deschide Codespaces
- În repo → butonul verde **Code** → **Codespaces** → **Create codespace on main**
- Aștepți ~2 minute să pornească (e un VS Code în browser)

### 4. Instalează Flutter în Codespace (copiază și rulează în terminal)

```bash
# Descarcă Flutter SDK
cd ~
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.22.0-stable.tar.xz
tar xf flutter_linux_3.22.0-stable.tar.xz
export PATH="$HOME/flutter/bin:$PATH"

# Verifică instalarea
flutter --version
```

### 5. Instalează dependențele și compilează APK

```bash
# Navighează în proiect
cd /workspaces/linkpi-android

# Descarcă dependențele
flutter pub get

# Compilează APK (release)
flutter build apk --release

# APK-ul e la:
# build/app/outputs/flutter-apk/app-release.apk
```

### 6. Descarcă APK-ul
- În panoul din stânga VS Code → `build/app/outputs/flutter-apk/`
- Click dreapta pe `app-release.apk` → **Download**

### 7. Instalează pe telefon
- Activează **Instalare din surse necunoscute** în setările telefonului
- Copiază APK pe telefon și instalează

---

## Alternativă: Replit

1. https://replit.com → Create Repl → **Flutter**
2. Importă fișierele
3. În Shell: `flutter build apk --release`

---

## Note tehnice

- **UDP Broadcast**: Asigură-te că router-ul permite broadcast între dispozitive (majoritatea rețelelor casnice permit)
- **Firewall**: Pe Windows, permite LinkPi pe porturile 50505 (TCP) și 50506 (UDP)
- **Aceeași rețea**: Telefonul și PC-ul trebuie să fie conectate la același Wi-Fi / router
- **Fișiere primite**: Se salvează în `Downloads/LinkPi_Downloads/` pe telefon

---

## Structura proiectului

```
lib/
├── main.dart                    # Entry point
├── models/
│   └── network_packet.dart      # Modele date (identic cu Windows)
├── helpers/
│   ├── ip_helper.dart           # Detectare IP local
│   ├── storage_helper.dart      # Persistență SharedPreferences
│   └── chat_controller.dart     # State management central
├── networking/
│   ├── udp_discovery.dart       # UDP broadcast/receive (port 50506)
│   ├── tcp_server.dart          # TCP server (port 50505)
│   └── tcp_client.dart          # TCP client cu graceful disconnect
└── screens/
    ├── setup_screen.dart        # Ecran introducere nume
    ├── home_screen.dart         # Lista utilizatori
    ├── chat_screen.dart         # Conversație + fișiere
    └── settings_screen.dart     # Setări profil/status
```
