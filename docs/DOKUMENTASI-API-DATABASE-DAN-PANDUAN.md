# Dokumentasi Database, REST API, Panduan Instalasi, dan Panduan Penggunaan — RakRapi

> **Disinkronkan dengan implementasi aktual:** 22 November 2026 (`codex/ui-env-pixel8`)  
> **Pengembang:** Muhammad Kaysan Ashraf — XI RPL 5 — SMK Taruna Bhakti (Uji Level KOKE & MAPIL 2026/2027)

---

## 1. Dokumentasi Database (`rakrapi`)

Database dijalankan pada **MySQL 8.0.30 (Laragon lokal)** dan **MySQL 8.4.11 (Aiven `TLSv1.3`)** dengan 6 tabel, 4 Foreign Key, serta stored procedure `tambah_pegawai` (dipertahankan pada database).

### A. Daftar 6 Tabel & Aturan Integritas

| Tabel | Primary Key | Foreign Key & Aturan Relasi | Constraint Penting |
|---|---|---|---|
| `users` | `id` (`INT UNSIGNED AI`) | — | `email UNIQUE`, `role IN ('pemilik','pegawai','warga')`, `DEFAULT 'warga'`, `password_hash` (bcrypt) |
| `kategori` | `id` (`INT UNSIGNED AI`) | — | `nama UNIQUE`, `CHAR_LENGTH(TRIM(nama)) > 0` |
| `barang` | `id` (`INT UNSIGNED AI`) | `fk_barang_kategori`: `kategori_id → kategori.id` (`ON DELETE RESTRICT`) | `stok >= 0`, `satuan IN ('botol','kg')`, botol wajib bulat (`stok = FLOOR(stok)`) |
| `lowongan` | `id` (`INT UNSIGNED AI`) | — | `aktif BOOLEAN DEFAULT true` |
| `pesanan` | `id` (`INT UNSIGNED AI`) | `pesanan_ibfk_1`: `warga_id → users.id` (`ON DELETE RESTRICT`) | `UNIQUE (warga_id, kunci_kirim)`, `status ENUM('Menunggu konfirmasi','Dikonfirmasi')` |
| `detail_pesanan` | `id` (`INT UNSIGNED AI`) | `detail_pesanan_ibfk_1`: `pesanan_id → pesanan.id` (`ON DELETE CASCADE`); `detail_pesanan_ibfk_2`: `barang_id → barang.id` (`ON DELETE SET NULL`) | `UNIQUE (pesanan_id, barang_id)`, `jumlah > 0`, menyalin harga/nama/satuan saat dipesan |

### B. Urutan SQL untuk Database Baru
Jalankan secara berurutan pada database kosong `rakrapi`:
1. `backend/database/01_skema.sql`
2. `backend/database/03_role_warga.sql`
3. `backend/database/04_prosedur_pegawai.sql`
4. `backend/database/05_lowongan.sql`
5. `backend/database/06_pesanan.sql`

*(Jangan menjalankan `02_demo.sql` pada database utama agar tidak menambahkan data dummy.)*

### C. Akun Runtime Database
- **Lokal (Laragon):** 1 akun aplikasi `rakrapi_app@localhost` (atau `root` Laragon bila tanpa sandi) dengan `DB_SSL=false`.
- **Cloud (Aiven):** 1 akun aplikasi non-admin `rakrapi_app@%` (`REQUIRE SSL`, izin hanya `SELECT, INSERT, UPDATE, DELETE ON rakrapi.*` dan `EXECUTE ON PROCEDURE rakrapi.tambah_pegawai`, **bukan `avnadmin`**) dengan `DB_SSL=true` dan `DB_SSL_CA_BASE64`.

---

## 2. Dokumentasi REST API (Base Path: `/api`)

Seluruh endpoint privat wajib mengirim header `Authorization: Bearer <token>` (JWT HS256, berlaku 1 jam).

| Group | Method & Path | Role Diizinkan | Input Utama | Status Respons |
|---|---|---|---|---|
| **Health** | `GET /api/health` | Publik | — | `200` `{ status: "ok", nama_database }`, `503` |
| **Auth** | `POST /api/auth/register` | Publik | `{ nama, email, password }` | `201` `{ user }` (role selalu `warga`), `400`, `409` |
| **Auth** | `POST /api/auth/login` | Publik | `{ email, password }` | `200` `{ token, user }`, `401` |
| **Auth** | `GET /api/auth/me` | 3 role | Bearer token | `200` `{ user }`, `401` |
| **Auth** | `GET /api/auth/pemilik` | `pemilik` | Bearer token | `200`, `401`, `403` |
| **Auth** | `POST /api/auth/pegawai` | `pemilik` | `{ nama, email, password }` | `201` `{ user }` (`pegawai`), `400`, `401`, `403`, `409` |
| **Kategori** | `GET /api/kategori` | `pemilik`, `pegawai` | Bearer token | `200` `{ data: [...] }`, `401`, `403` |
| **Kategori** | `GET /api/kategori/:id` | `pemilik` | Param `id` | `200` `{ data }`, `400`, `401`, `403`, `404` |
| **Kategori** | `POST /api/kategori` | `pemilik` | `{ nama }` | `201` `{ data }`, `400`, `401`, `403`, `409` |
| **Kategori** | `PATCH /api/kategori/:id` | `pemilik` | `{ nama }` | `200` `{ data }`, `400`, `401`, `403`, `404`, `409` |
| **Kategori** | `DELETE /api/kategori/:id` | `pemilik` | Param `id` | `204`, `400`, `401`, `403`, `404`, `409` (masih dipakai) |
| **Barang** | `GET /api/barang` | 3 role | Bearer token | `200` `{ data: [...] }` (`INNER JOIN kategori` + `foto_url`) |
| **Barang** | `GET /api/barang/:id` | 3 role | Param `id` | `200` `{ data }`, `400`, `401`, `404` |
| **Barang** | `GET /api/barang/:id/foto` | 3 role | Param `id` | `200` (byte JPEG/PNG), `401`, `404`, `503` |
| **Barang** | `POST /api/barang` | `pemilik`, `pegawai` | `multipart/form-data` (`nama`, `kategori_id`, `harga_rupiah`, `stok`, `satuan`, file `foto`) | `201` `{ data }`, `400`, `401`, `403`, `413`, `415` |
| **Barang** | `PATCH /api/barang/:id` | `pemilik`, `pegawai` | JSON atau `multipart/form-data` | `200` `{ data }`, `400`, `401`, `403`, `404`, `409`, `413`, `415` |
| **Barang** | `DELETE /api/barang/:id` | `pemilik` | Param `id` | `204`, `400`, `401`, `403`, `404` |
| **Lowongan** | `GET /api/lowongan` | `pemilik`, `warga` | Bearer token | `200` `{ data: [...] }` (warga: aktif saja; pemilik: semua) |
| **Lowongan** | `POST /api/lowongan` | `pemilik` | `{ judul }` | `201` `{ data }`, `400`, `401`, `403` |
| **Lowongan** | `PATCH /api/lowongan/:id/tutup` | `pemilik` | Param `id` | `204`, `400`, `401`, `403`, `404` |
| **Pesanan** | `POST /api/pesanan` | `warga` | `{ kunci_kirim, item: [{ barang_id, jumlah, satuan }] }` | `201` `{ data }`, `400`, `401`, `403`, `409` |
| **Pesanan** | `GET /api/pesanan` | 3 role | Bearer token | `200` `{ data: [...] }` (warga: miliknya; toko: semua) |
| **Pesanan** | `GET /api/pesanan/:id` | 3 role | Param `id` | `200` `{ data }` (+ `item` & `subtotal_rupiah`), `404` |
| **Pesanan** | `PATCH /api/pesanan/:id/konfirmasi` | `pemilik`, `pegawai` | Param `id` | `200` `{ data }` (`Dikonfirmasi`), `403`, `404`, `409` (stok kurang) |

---

## 3. Panduan Instalasi (Lokal & Aiven)

### Prasyarat
- **Node.js 22.9+** (`>=22.9.0 <23.0.0`)
- **MySQL 8** (Laragon lokal atau layanan Aiven MySQL)
- **Flutter SDK 3.x** & Android SDK (untuk menjalankan/build aplikasi Android)

### Langkah Menjalankan Backend
```powershell
Set-Location C:\Users\Kaysan\UjiLevel\backend
Copy-Item .env.example .env   # lalu isi nilai privat di .env (jangan commit ke Git)
npm.cmd ci
npm.cmd run build
npm.cmd start
```
Verifikasi API aktif:
```powershell
curl.exe -i http://127.0.0.1:3000/api/health
# Hasil yang diharapkan: HTTP 200 {"status":"ok","nama_database":"rakrapi"}
```

### Langkah Menjalankan Aplikasi Android (Emulator / HP USB)
```powershell
Set-Location C:\Users\Kaysan\UjiLevel\frontend
C:\flutter\bin\flutter.bat pub get
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s <ID_PERANGKAT> reverse tcp:3000 tcp:3000
C:\flutter\bin\flutter.bat run -d <ID_PERANGKAT>
```
Untuk build APK rilis (opsional mengatur URL API khusus LAN/internet dengan `--dart-define=API_URL=...`):
```powershell
C:\flutter\bin\flutter.bat build apk --release
# Output: frontend/build/app/outputs/flutter-apk/app-release.apk
```

---

## 4. Panduan Penggunaan Aplikasi (Per Peran)

1. **Pengunjung (Belum Masuk):**
   - Buka aplikasi → tampil layar **Masuk ke Akun**.
   - Pilih **Daftar sebagai warga** untuk membuat akun baru (`role: warga`), atau langsung masuk jika sudah punya akun.
2. **Warga (`role: warga`):**
   - Navigasi bawah memiliki 3 tab: **Katalog**, **Lowongan**, dan **Bansos** *(menampilkan keterangan jujur bahwa layanan bansos sedang disiapkan)*.
   - Buka produk di **Katalog** → tentukan jumlah (`botol` bulat, `kg` boleh pecahan mis. `1,25`) → masukkan ke **Keranjang** → buka ikon keranjang → klik **Kirim pesanan**.
   - Pantau status pesanan (`Menunggu konfirmasi` → `Dikonfirmasi`) melalui ikon **Pesanan saya**.
   - Klik ikon **Keluar** untuk logout dan menghapus token sesi.
3. **Pegawai (`role: pegawai`):**
   - Masuk dari layar login yang sama → langsung ke **Katalog**.
   - Klik **Tambah barang** untuk menambah produk baru beserta foto dari galeri, atau buka produk lalu klik **Ubah** untuk memperbarui harga/stok/foto.
   - Buka ikon **Pesanan masuk** → pilih pesanan warga → klik **Konfirmasi pesanan** untuk mengurangi stok secara otomatis dalam satu transaksi.
4. **Pemilik Toko (`role: pemilik`):**
   - Memiliki seluruh kemampuan pegawai, ditambah **Hapus barang** (dengan dialog konfirmasi) dan **Menu pemilik (⋮)**:
     - **Kelola kategori:** tambah, ubah, atau hapus kategori (kategori yang masih dipakai barang otomatis ditolak).
     - **Tambah pegawai:** membuat akun baru dengan role `pegawai`.
     - **Kelola lowongan:** membuka atau menutup lowongan kerja toko.
