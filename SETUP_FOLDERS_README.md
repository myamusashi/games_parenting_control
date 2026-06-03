# Setup Folder Structure untuk Games Parenting Control

Script ini akan membuat struktur folder lengkap untuk kedua aplikasi Flutter.

## 📋 Persyaratan
- Linux/macOS atau WSL (Windows Subsystem for Linux)
- Bash shell
- `mkdir` command (built-in)

## 🚀 Cara Penggunaan

### 1. Dari Root Repository
```bash
chmod +x setup_folders.sh
./setup_folders.sh
```

### 2. Atau jalankan langsung tanpa chmod
```bash
bash setup_folders.sh
```

## 📁 Struktur yang Akan Dibuat

### gamesbox_parent/
```
lib/
├── screens/
│   ├── auth/                 (login, register, pairing setup)
│   ├── games/                (manage games - CRUD)
│   ├── time_limits/          (set daily time limits)
│   ├── dashboard/            (parent dashboard)
│   └── settings/             (parent settings)
├── models/                   (data models)
├── services/                 (firebase, auth, games, pairing)
├── widgets/                  (reusable components)
└── utils/                    (constants, helpers)
```

### gamesbox_kids/
```
lib/
├── screens/
│   ├── auth/                 (OTP/password login, pairing)
│   ├── games/                (games list, game play)
│   ├── dashboard/            (kids dashboard)
│   └── settings/             (kids settings)
├── models/                   (data models)
├── services/                 (firebase, auth, games, timer)
├── widgets/                  (reusable components)
└── utils/                    (constants, helpers)
```

## ✅ Output

Script akan:
1. ✓ Membuat semua folder yang diperlukan
2. ✓ Membuat `.gitkeep` file untuk setiap folder (agar git track empty folders)
3. ✓ Menampilkan summary struktur folder
4. ✓ Memberikan next steps

## 🎯 Setelah Script Selesai

### 1. Update pubspec.yaml untuk gamesbox_kids
Tambahkan dependencies yang hilang:
```bash
cd gamesbox_kids
```

Edit `pubspec.yaml` dan tambahkan di bagian dependencies:
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  cupertino_icons: ^1.0.8
  shared_preferences: ^2.5.5
  installed_apps: ^2.1.1
  usage_stats: ^1.3.1
  
  # Tambahkan yang berikut ini:
  firebase_database: ^12.4.2
  firebase_core: ^4.10.0
  firebase_auth: ^6.5.2
  mobile_scanner: ^7.2.0
  otp: ^3.2.0
```

Kemudian jalankan:
```bash
flutter pub get
```

### 2. Mulai Membuat Models
```bash
# Di gamesbox_parent/lib/models/
touch user_model.dart
touch game_model.dart
touch child_model.dart
touch time_limit_model.dart

# Di gamesbox_kids/lib/models/
touch user_model.dart
touch game_model.dart
touch time_limit_model.dart
```

### 3. Mulai Membuat Services
```bash
# Di gamesbox_parent/lib/services/
touch firebase_service.dart
touch auth_service.dart
touch games_service.dart
touch pairing_service.dart
touch time_limit_service.dart

# Di gamesbox_kids/lib/services/
touch firebase_service.dart
touch auth_service.dart
touch games_service.dart
touch pairing_service.dart
touch timer_service.dart
```

## 🔧 Troubleshooting

### Permission Denied
```bash
chmod +x setup_folders.sh
```

### Folders already exist
Script akan skip folders yang sudah ada dan langsung membuat yang belum.

### Need to undo
```bash
rm -rf gamesbox_parent/lib gamesbox_kids/lib
./setup_folders.sh
```

## 📝 Notes

- Semua folder memiliki file `.gitkeep` agar git bisa track empty directories
- Anda bisa menghapus `.gitkeep` setelah menambahkan file `.dart` pertama
- Struktur mengikuti best practices Flutter project organization

---

Happy coding! 🚀
