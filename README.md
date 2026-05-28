# Cofflow Customer App

Aplikasi Flutter untuk pelanggan coffee shop **Cofflow**. Browse menu, pesan, bayar, dan lacak status pesanan. Berkomunikasi dengan backend Laravel lewat REST API (Dio + token Sanctum). Tidak ada koneksi langsung ke database — semua data lewat API.

> **Catatan migrasi:** versi awal app ini memakai Supabase (auth + realtime + query tabel langsung). Sekarang **sepenuhnya pakai backend Laravel** (`cofflowdashboard`). Supabase sudah dihapus dari app.

Bagian dari ekosistem Cofflow: backend REST API + admin web + employee app + customer app (repo ini).

---

## Fitur

- **Auth** — register (nama, email, HP opsional, password) & login. Register langsung login (token dipersist).
- **Browse Menu** — daftar menu dari `/menus`, filter kategori dinamis dari `/categories` (Semua + nama kategori).
- **Detail Produk** — pilih jenis susu & tingkat kemanisan. Pilihan dikirim sebagai `notes` per item order (belum dipetakan ke condiment_option backend).
- **Keranjang** — tambah/kurang qty, hapus item.
- **Checkout + Payment Picker** — pilih metode: **Cash** / **QRIS** / **Virtual Account** (bank: bca/bni/bri/mandiri).
  - Cash → langsung masuk tab Pesanan.
  - QRIS → tampil QR (`qr_code_url` dari Midtrans), polling status bayar tiap 4 detik.
  - VA → tampil nomor VA + bank, polling status bayar.
- **Tracking Pesanan** — timeline status via **polling tiap 5 detik** (backend tanpa realtime): `pending → processing → ready → completed` (label Indonesia). Nomor antrian + estimasi.
- **Profil** — data dari `/auth/me` (nama, email, HP, role). Riwayat pesanan dari `GET /orders`.

### Out of Scope
- Loyalty / flow points (backend belum sediakan endpoint customer points)
- Pemetaan condiment asli (saat ini milk/sweetness → free-text note)
- Fitur staff/admin

---

## Tech Stack

| Layer | Teknologi |
|-------|-----------|
| Framework | Flutter 3.44.x (Dart 3.11) |
| State Management | `StatefulWidget` + `setState` + static `AppState` |
| HTTP | `dio` ^5.4 |
| Secure Storage | `flutter_secure_storage` ^9.0 (token Sanctum) |
| Routing | `Navigator` (MaterialPageRoute) + `navigatorKey` global |
| Fonts | `google_fonts` ^6.1 (Plus Jakarta Sans) |
| Icons | `lucide_icons_flutter` ^3.0 |
| Animation | `animations` ^2.0 |

> **Kenapa `lucide_icons_flutter`, bukan `lucide_icons`?** Flutter 3.44 menjadikan `IconData` sebagai `final class`, yang membuat `lucide_icons` 0.257.0 gagal compile. Fork `lucide_icons_flutter` kompatibel dan memakai nama icon yang sama (`LucideIcons.*`).

---

## Struktur Folder

```
lib/
├── core/
│   ├── constants/        ← app_constants.dart (baseUrl, timeout, storage keys)
│   ├── network/          ← api_client.dart (Dio + auth interceptor + 401 handler), api_endpoints.dart
│   ├── storage/          ← token_storage.dart (flutter_secure_storage)
│   └── utils/            ← json_parse.dart (parse decimal string / int / bool / date)
├── services/
│   └── api_services.dart ← AuthService, ProductService, OrderService, ProfileService + ApiException
├── models.dart           ← Product, CartItem, Order (+status mapping), UserProfile
└── main.dart             ← App, AppState, semua screen + payment picker/screen
```

---

## Setup

### 1. Prasyarat
- Flutter SDK 3.44.x (Dart 3.11)
- Android Studio + emulator/device, atau Chrome/desktop untuk dev cepat
- Backend `cofflowdashboard` running (lokal atau via tunnel)

### 2. Install
```bash
flutter pub get
```

### 3. Konfigurasi backend URL
Backend URL via `--dart-define`. **Jangan hardcode URL production.**

```bash
# Android emulator → host loopback (default jika tanpa flag)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api

# Device fisik via LAN
flutter run --dart-define=API_BASE_URL=http://<host-LAN-ip>:8000/api

# Web / iOS sim / desktop
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api

# Production / Cloudflare tunnel
flutter run --dart-define=API_BASE_URL=https://<api-host>/api
```

Default fallback ada di [lib/core/constants/app_constants.dart](lib/core/constants/app_constants.dart) (`http://10.0.2.2:8000/api`).

### 4. Run
```bash
flutter run --dart-define=API_BASE_URL=<your-api-url>
```

---

## Test Account

Pakai akun seeded backend atau register baru lewat app.

| Email | Password | Role |
|---|---|---|
| `customer@cofflow.test` | `password` | customer |

Atau tap **DAFTAR** di login screen untuk buat akun customer baru (langsung login).

---

## Test Flow End-to-End

1. Login (atau register) → masuk Home
2. Pilih kategori → menu ter-filter
3. Tap produk → pilih susu + kemanisan + qty → TAMBAH → masuk keranjang
4. Tab Keranjang → atur qty / hapus → **PILIH PEMBAYARAN**
5. Sheet metode bayar → pilih Cash / QRIS / VA (+bank) → **PESAN SEKARANG**
6. Cash → tab Pesanan, timeline mulai polling. QRIS/VA → layar pembayaran, polling status
7. (Backend) ubah status order via Employee App / Admin → customer lihat timeline update tiap 5 detik
8. Status `completed` → dialog sukses
9. Profil → Riwayat Pesanan → list dari backend
10. Keluar → token cleared → balik ke Login

---

## API Endpoints yang Dipakai

Format response: `{ "success": true, "data": ..., "message": "OK" }`.

| Method | Endpoint | Pakai |
|---|---|---|
| POST | `/auth/register` | register + token |
| POST | `/auth/login` | login + token |
| POST | `/auth/logout` | logout |
| GET | `/auth/me` | profil |
| GET | `/menus` | daftar menu |
| GET | `/categories` | filter kategori |
| POST | `/orders` | buat order (order_type, payment_method, items[]) |
| GET | `/orders` | riwayat |
| GET | `/orders/{id}` | poll status + payment |

---

## Keamanan

- Token Sanctum disimpan via `flutter_secure_storage` (Android: EncryptedSharedPreferences). Hanya token — bukan password.
- `Authorization: Bearer <token>` di-attach otomatis oleh interceptor ke semua request.
- Response 401 → token di-clear + redirect ke Login (`ApiClient.onUnauthorized`).
- Timeout 30 detik (connect + receive).
- `LogInterceptor` Dio aktif HANYA di `kDebugMode` — off otomatis di release.
- Pakai HTTPS di production. `cleartextTraffic` hanya untuk dev lokal.

---

## Build

```bash
# Debug
flutter run --dart-define=API_BASE_URL=<api-url>

# Release APK
flutter build apk --release --dart-define=API_BASE_URL=<api-url>

# Lint
flutter analyze
```

---

## Lisensi

Internal use only — Cofflow project.
