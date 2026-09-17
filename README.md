# 🌾 AgriNova

Aplikasi mobile pintar untuk membantu petani Indonesia dengan informasi cuaca real-time, tips pertanian, kalender tanam, sistem peringatan berbasis cuaca, **deteksi penyakit tanaman berbasis AI**, **katalog obat tanaman**, dan **chatbot Asisten Tani**.

## 📚 Dokumentasi Utama

| Dokumen                                 | Deskripsi                                          |
| --------------------------------------- | -------------------------------------------------- |
| [📖 DOCS.md](./docs/DOCS.md)                 | Dokumentasi teknis & arsitektur lengkap            |
| [🔌 API.md](./docs/API.md)                   | Dokumentasi integrasi API (Supabase & OpenWeather) |
| [🗄️ ERD.md](./docs/ERD.md)                   | Struktur database & diagram ERD (Supabase)         |
| [🔄 SEQUENCE_DIAGRAM.md](./docs/SEQUENCE_DIAGRAM.md) | Sequence diagram interaksi antar komponen      |
| [🏃 ACTIVITY_DIAGRAM.md](./docs/ACTIVITY_DIAGRAM.md) | Activity diagram alur & logika keputusan       |
| [🤝 CONTRIBUTING.md](./CONTRIBUTING.md) | Panduan kontribusi developer                       |
| [📋 CHANGELOG.md](./CHANGELOG.md)       | Riwayat perubahan versi                            |

## 🚀 Fitur Utama

### 🔐 Autentikasi Pengguna

- **Login & Register**: Email dan password via Supabase Auth dengan validasi form.
- **Reset Password**: Kirim email reset password langsung dari aplikasi.
- **Onboarding**: Tampilan panduan pertama kali untuk pengguna baru.
- **Session Persistence**: Sesi login tetap aktif antar buka aplikasi.

### 🌤️ Sistem Cuaca Cerdas

- **Real-time Weather**: Data akurat dari OpenWeatherMap.
- **Prediksi Per Jam**: Prakiraan cuaca detail untuk 24 jam ke depan.
- **Weather Alerts**: Notifikasi otomatis saat ada potensi **Hujan Deras**, **Angin Kencang**, atau **Badai Petir**.
- **Analisis Risiko Hama**: Deteksi potensi serangan hama berdasarkan suhu dan kelembaban.

### 🔔 Notifikasi Pintar (Background System)

- **Morning Briefing**: Sapaan pagi dengan ringkasan cuaca hari ini (06:00).
- **Smart Calendar**: Pengingat jadwal tanam/pupuk (H-1, H-1 Jam, dan Hari H).
- **Quiet Mode**: Mode "Tenang" otomatis di malam hari (22:00 - 05:00) agar istirahat tidak terganggu.
- **Offline Support**: Notifikasi tetap berjalan meski aplikasi ditutup (menggunakan `Workmanager` & `AlarmManager`).

### 📅 Kalender Tanam Digital

- **Manajemen Jadwal**: Tambah, Edit, Hapus jadwal kegiatan tani.
- **Sinkronisasi Notifikasi**: Jadwal yang diedit otomatis memperbarui alarm notifikasi.
- **Rekomendasi Bulanan**: Saran aktivitas pertanian berdasarkan bulan berjalan.

### 📚 Tips & Edukasi

- **Konten Terkurasi**: Tips budidaya Padi, Jagung, dan Nutrisi Tanaman.
- **Offline Cache**: Artikel tersimpan lokal, baca kapan saja tanpa internet.

### 🔬 Scanner Penyakit Tanaman (AI)

- **Deteksi via Foto**: Ambil foto daun dari kamera atau galeri — mendukung **Tomat**, **Padi**, dan **Teh**.
- **Auto-Detect Tanaman**: Mode otomatis mendeteksi jenis tanaman sebelum menganalisis penyakit; atau pilih manual via chip tanaman.
- **Multi-Model Inference**: Tomat via cloud URL (`MODEL_TOMATO`), Padi & Teh via HuggingFace multipart. Gambar di-upload ke Supabase Storage sebelum dianalisis.
- **Detail Penyakit**: Deskripsi, langkah penanganan, dan **rekomendasi obat** diambil dari tabel `penyakit_tomat` / `penyakit_padi` / `penyakit_teh` di Supabase sesuai tanaman terdeteksi.
- **Auto-Save History**: Setiap hasil scan otomatis tersimpan ke riwayat prediksi.

### 💊 Katalog Obat Tanaman

- **Database Lokal**: Daftar obat/pestisida dari aset `katalog_obat_tanaman.json` (tanpa internet).
- **Detail Lengkap**: Bahan aktif, dosis, cara pakai, produsen, sasaran hama/penyakit, dan tanaman target.
- **Pencarian & Filter**: Cari berdasarkan nama, bahan aktif, sasaran; filter kategori (termasuk Organik) dengan layout grid/list.

### 📜 Riwayat Prediksi (History)

- **Sinkronisasi Cloud**: Riwayat hasil scan tersimpan di Supabase (`prediction_history`).
- **Offline-First**: Ambil dari Supabase dulu, fallback ke cache lokal Hive jika offline.
- **Manajemen**: Hapus satu per satu atau hapus semua riwayat.

### 🤖 Chatbot Asisten Tani (Gemini AI)

- **Streaming Jawaban**: Respons real-time token-per-token via Google Gemini (`gemini-2.5-flash`).
- **Context-Aware**: Menyuntikkan konteks cuaca terkini & daftar hama aktif ke prompt agar jawaban relevan.
- **Domain-Locked**: System prompt membatasi topik hanya seputar pertanian.
- **Prompt-Injection Guard**: Sanitasi input (batas 500 karakter + blokir pola berbahaya seperti "ignore previous", "jailbreak", dll).

### 🔔 Riwayat Notifikasi

- **Notification History**: Semua notifikasi tersimpan di Hive box terenkripsi, dengan sorting terbaru & hapus per item.

### 👤 Manajemen Profil & Support

- **Profil Lokal**: Personalisasi nama dan foto pengguna.
- **Bantuan Pengguna**: Layanan support via email terintegrasi.
- **Transparansi**: Informasi lengkap tentang aplikasi dan versi.

### � Security (OWASP MASVS Compliant)

- **Encrypted Storage**: Data lokal terenkripsi dengan AES-256.
- **Secure Key Management**: Kunci enkripsi tersimpan di Android Keystore/iOS Keychain.
- **Code Protection**: ProGuard obfuscation & R8 minification.
- **No Data Backup**: Mencegah ekstraksi data via backup.

### 🌍 Multi-Language Support

- **Bahasa Indonesia & English**: Switch bahasa melalui Settings.
- **Localized Content**: UI, notifikasi, dan konten tersedia dalam 2 bahasa.

## �🛠️ Tech Stack & Architecture

Aplikasi ini dibangun dengan **Clean Architecture** dan **BLoC Pattern** untuk skalabilitas maksimal.

| Layer                  | Technology                                       |
| ---------------------- | ------------------------------------------------ |
| **Language**           | Dart (Flutter 3.x)                               |
| **State Management**   | **Flutter BLoC** (Business Logic Component)      |
| **Architecture**       | Feature-First (Data, Domain, Presentation)       |
| **Backend**            | Supabase (PostgreSQL, Auth, Storage)             |
| **Weather API**        | OpenWeatherMap                                   |
| **Disease Detection**  | Multi-model via HuggingFace — Tomat (cloud URL), Padi & Teh (multipart), Auto-detect |
| **Conversational AI**  | Google Gemini (`gemini-2.5-flash`, streaming SSE) |
| **Local Storage**      | Hive (NoSQL Database) with AES-256 Encryption    |
| **Secure Storage**     | Flutter Secure Storage (Keystore/Keychain)       |
| **Background Service** | Workmanager & Android Alarm Manager              |
| **Notifications**      | Flutter Local Notifications                      |
| **Localization**       | Easy Localization (ID/EN)                        |
| **Security**           | ProGuard, R8 Minification, OWASP MASVS Compliant |

## 📋 Riwayat Versi

| Versi | Tanggal    | Deskripsi                                  |
| ----- | ---------- | ------------------------------------------ |
| 0.6.0 | 2026-06-24 | AI Suite: Scanner Penyakit, Katalog Obat, Riwayat Prediksi, Chatbot Gemini |
| 0.5.0 | 2026-01-11 | Localization (ID/EN) & Skeleton Loading UI |
| 0.4.0 | 2026-01-11 | Profile, Support, & Security (OWASP MASVS) |
| 0.3.0 | 2025-12-31 | BLoC Refactor & Smart Notifications        |
| 0.2.0 | 2025-12-21 | Offline Mode & Stability                   |
| 0.1.0 | 2025-12-17 | Initial Release (Weather & Calendar Core)  |

## 📦 Dependencies Utama

```yaml
dependencies:
  flutter_bloc: ^8.1.6
  equatable: ^2.0.7
  supabase_flutter: ^2.0.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^10.0.0 # Secure key storage
  workmanager: ^0.9.0+3
  flutter_local_notifications: ^17.0.0
  geolocator: ^14.0.2
  http: ^1.6.0
  intl: ^0.20.2
  table_calendar: ^3.1.2
  easy_localization: ^3.0.8 # Multi-language
  shimmer: ^3.0.0 # Skeleton loading
  cached_network_image: ^3.4.1 # Image caching
  google_generative_ai: ">=0.4.7 <2.0.0" # Chatbot (Gemini)
  flutter_dotenv: ^6.0.1 # Load .env variables
  image_picker: ^1.1.0 # Ambil foto untuk scanner
  flutter_cache_manager: ^3.4.1 # Cache file/gambar
  url_launcher: ^6.2.0 # Email support
```

## 📂 Struktur Project (Feature-First)

```
lib/
├── core/                   # Shared logic & services
│   ├── services/           # Background, Notification, Cache, Connectivity
│   ├── constants/          # Colors, API Keys, EnvConfig
│   └── theme/              # App Themes
├── data/                   # Data Layer
│   ├── datasources/        # API & Local DB (weather, pest, scanner, chatbot, ...)
│   ├── repositories/       # Data mediation logic
│   └── models/             # Data classes (chat_message, prediction_history, ...)
├── features/               # Feature Modules
│   ├── home/               # HomeLogic, BLoC, UI, Skeleton
│   ├── calendar/           # CalendarLogic, BLoC, UI
│   ├── tips/               # TipsLogic, BLoC, UI
│   ├── pests/              # Hama & Penyakit Tanaman
│   ├── scanner/            # Deteksi penyakit via AI (BLoC + UI)
│   ├── drugs/              # Katalog obat tanaman
│   ├── history/            # Riwayat prediksi (BLoC + UI)
│   ├── chatbot/            # Asisten Tani (Gemini, BLoC + UI)
│   ├── weather/            # WeatherUI & Detail
│   ├── settings/           # Profile, Notifikasi, Bahasa
│   ├── onboarding/         # First-time User Guide
│   └── notifications/      # Notification History
├── logic/                  # Global BLoC (app lifecycle)
├── widgets/                # Reusable global widgets
├── utils/                  # Helper utilities
└── main.dart               # Entry point & DI Setup
```

## 🚀 Cara Menjalankan

### Persyaratan

- Flutter SDK >= 3.0.0
- Device/Emulator Android (Min SDK 21)

### Langkah Instalasi

1. **Clone Repository**

   ```bash
   git clone https://github.com/AffanShz/AgriNova.git
   cd agrinova
   ```

2. **Setup Environment Variable**

   Buat file `.env` di root folder (sejajar dengan `pubspec.yaml`) dan isi dengan kredensial berikut:

   ```env
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   OPENWEATHER_API_KEY=your_openweather_api_key
   MODEL_TOMATO=your_model_tomato_api_url   # Endpoint model deteksi penyakit (Scanner)
   GEMINI_API_KEY=your_gemini_api_key       # Google Gemini (Chatbot Asisten Tani)
   ```

   > 💡 `MODEL_TOMATO` & `GEMINI_API_KEY` wajib untuk fitur Scanner & Chatbot. Tanpa keduanya, fitur tersebut tidak berfungsi (default `MODEL_TOMATO` fallback ke endpoint demo Hugging Face).

   **📋 Cara mendapatkan credential:**

   **A. Supabase URL & Anon Key**
   - Buka [supabase.com](https://supabase.com) → Login
   - Pilih project Anda → Settings → API
   - Copy `Project URL` → paste ke `SUPABASE_URL`
   - Copy `anon public` key → paste ke `SUPABASE_ANON_KEY`
   
   **Contoh:**
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

   **B. OpenWeather API Key**
   - Buka [openweathermap.org](https://openweathermap.org) → Sign Up
   - Pilih menu **API Keys** di dashboard
   - Copy API key default (atau buat baru) → paste ke `OPENWEATHER_API_KEY`
   
   **Contoh:**
   ```env
   OPENWEATHER_API_KEY=abc123def456ghi789jkl012mno34567pqr
   ```

   **C. Gemini API Key (Chatbot)**
   - Buka [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey) → Login Google
   - Klik **Create API Key** → copy → paste ke `GEMINI_API_KEY`

   **D. Model Tomato URL (Scanner)**
   - URL endpoint model deteksi penyakit (mengekspos `POST /predict`)
   - Paste base URL ke `MODEL_TOMATO` (contoh: `https://xxxx.hf.space`)

   ⚠️ **Penting:**
   - File `.env` sudah ada di `.gitignore` (tidak akan ter-push ke GitHub)
   - Jangan commit credential ke repository
   - Buat kredensial test untuk development (bukan production)

3. **Install Dependencies**

   ```bash
   flutter pub get
   ```

4. **Jalankan Aplikasi**
   ```bash
   flutter run --dart-define-from-file=.env
   ```

## 🔄 Alur Caching (Offline First)

```
User Membuka Fitur
       │
[Cek Koneksi Internet]
       │
   ┌───▼───┐
   │       │
(Online) (Offline)
   │       │
Load API   Load Hive Cache
   │       │
Simpan ke  Tampilkan Data
 Cache     (Snackbar: "Mode Offline")
   │
Update UI
```

## 🐛 Troubleshooting

### ❌ Error: "Gagal memuat data. Periksa koneksi internet..."

Pesan ini muncul ketika aplikasi **tidak bisa mengakses Supabase atau OpenWeatherMap API**.

**Penyebab & Solusi:**

| Error | Penyebab | Solusi |
|-------|---------|--------|
| `Supabase URL is null` | `.env` tidak ditemukan atau tidak diload | ✅ Pastikan file `.env` ada di root folder (sejajar `pubspec.yaml`) |
| `Invalid SUPABASE_ANON_KEY` | Credential salah atau format salah | ✅ Copy ulang dari Supabase dashboard → paste di `.env` |
| `OPENWEATHER_API_KEY is empty` | API key tidak dikonfigurasi | ✅ Buat API key di openweathermap.org → paste ke `.env` |
| `Network timeout` | Internet lambat atau endpoint down | ✅ Cek koneksi internet, tunggu beberapa detik, coba lagi |
| `Database table not found` | Tabel di Supabase belum dibuat | ✅ Buat tabel: `tips`, `hama`, `penyakit_tomat`, `penyakit_padi`, `penyakit_teh`, `prediction_history` di Supabase |

**Langkah Debug:**

1. **Verifikasi `.env` sudah ada:**
   ```bash
   ls -la .env  # Linux/Mac
   dir .env     # Windows
   ```

2. **Periksa format `.env`:**
   ```env
   # ✅ BENAR
   SUPABASE_URL=https://your-project.supabase.co
   OPENWEATHER_API_KEY=abc123...

   # ❌ SALAH (ada spasi)
   SUPABASE_URL = https://your-project.supabase.co
   ```

3. **Restart Flutter:**
   ```bash
   flutter clean
   flutter pub get
   flutter run --dart-define-from-file=.env
   ```

4. **Cek log terminal** untuk error detail:
   - Lihat pesan error di terminal Flutter
   - Gunakan `flutter run -v` untuk verbose logging

### ✅ Jika masih gagal:

1. Buka [supabase.com](https://supabase.com) → Dashboard
2. Verifikasi project **aktif** dan **online**
3. Cek **Tables** → pastikan tabel `tips`, `hama`, `penyakit_tomat`, dll. ada data
4. Settings → **API** → copy URL dan key **yang benar**
5. Restart app dan coba lagi

---

_Dibuat dengan ❤️ untuk kemajuan pertanian Indonesia._ :))
