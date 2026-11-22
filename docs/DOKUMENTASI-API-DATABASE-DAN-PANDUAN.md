# Dokumentasi Database, REST API, Panduan Instalasi, dan Panduan Penggunaan — RakRapi (V3)

> **Disinkronkan dengan implementasi aktual V3:** 22 November 2026 (`codex/ui-env-pixel8`)  
> **Pengembang:** Muhammad Kaysan Ashraf — XI RPL 5 — SMK Taruna Bhakti (Uji Level KOKE & MAPIL 2026/2027)

---

## 1. Dokumentasi Database (`rakrapi`)

Database dijalankan pada **MySQL 8.4.11 (Aiven `TLSv1.3` — target runtime aktif di `.env`)** dan disinkronkan pula pada **MySQL 8.0.30 (Laragon lokal)** dengan **11 tabel**, **8 Foreign Key**, serta stored procedure `tambah_pegawai` yang tetap dipertahankan.

### A. Daftar 11 Tabel & Aturan Integritas

| No | Tabel | Primary Key | Foreign Key & Relasi | Constraint & Catatan Penting |
|---:|---|---|---|---|
| 1 | `users` | `id` (`INT UNSIGNED AI`) | — | `email UNIQUE`, `role IN ('pemilik','pegawai','warga')`, `password_hash` (`bcryptjs`), `status ENUM('aktif','diberhentikan') DEFAULT 'aktif'`, `alasan_pemberhentian`, `diberhentikan_pada` |
| 2 | `kategori` | `id` (`INT UNSIGNED AI`) | — | `nama UNIQUE`, `CHAR_LENGTH(TRIM(nama)) > 0` |
| 3 | `barang` | `id` (`INT UNSIGNED AI`) | `fk_barang_kategori`: `kategori_id → kategori.id` (`ON DELETE RESTRICT`) | `stok >= 0`, 9 satuan valid (`botol`, `kg`, `pcs`, `bungkus`, `pack`, `sisir`, `kotak`, `lembar`, `sachet`), `satuan = 'kg' OR stok = FLOOR(stok)`, kolom `deskripsi` |
| 4 | `pesanan` | `id` (`INT UNSIGNED AI`) | `pesanan_ibfk_1`: `warga_id → users.id` (`ON DELETE RESTRICT`) | `UNIQUE (warga_id, kunci_kirim)`, `status` (`Menunggu konfirmasi`, `Dikonfirmasi`, `Siap diambil`, `Selesai`), `metode_pembayaran` (`Bayar di kasir`, `Transfer bank`), `status_pembayaran` (`Belum dibayar`, `Sudah dibayar`) |
| 5 | `detail_pesanan` | `id` (`INT UNSIGNED AI`) | `detail_pesanan_ibfk_1`: `pesanan_id → pesanan.id`; `detail_pesanan_ibfk_2`: `barang_id → barang.id` (`ON DELETE SET NULL`) | `UNIQUE (pesanan_id, barang_id)`, `jumlah > 0`, menyalin harga/nama/satuan saat dipesan |
| 6 | `lowongan` | `id` (`INT UNSIGNED AI`) | — | `deskripsi`, `persyaratan`, `lokasi`, `info_tambahan`, `foto_key` (opsional), `aktif`, `is_pinned`, `dibuat` |
| 7 | `lamaran` | `id` (`INT UNSIGNED AI`) | `fk_lamaran_lowongan`: `lowongan_id → lowongan.id` (`ON DELETE CASCADE`); `fk_lamaran_warga`: `warga_id → users.id` (`ON DELETE RESTRICT`) | `UNIQUE (lowongan_id, warga_id)` mencegah lamaran ganda; `status` (`Menunggu verifikasi`, `Disetujui`, `Ditolak`) |
| 8 | `program_bansos` | `id` (`INT UNSIGNED AI`) | — | `nama`, `deskripsi`, `jenis_bantuan`, `persyaratan`, `kuota >= 1`, `foto_key`, `aktif`, `is_pinned`, `dibuat` |
| 9 | `pengajuan_bansos` | `id` (`INT UNSIGNED AI`) | `fk_pengajuan_program`: `program_id → program_bansos.id` (`ON DELETE CASCADE`); `fk_pengajuan_warga`: `warga_id → users.id` (`ON DELETE RESTRICT`) | `UNIQUE (program_id, warga_id)` mencegah pengajuan ganda; `status` (`Menunggu verifikasi`, `Disetujui`, `Ditolak`); tanpa NIK/penghasilan fiktif |
| 10 | `pengumuman` | `id` (`INT UNSIGNED AI`) | — | `judul`, `deskripsi`, `jenis` (`Pengumuman`, `Diskon`, `Informasi toko`), `info_tambahan`, `foto_key`, `aktif`, `is_pinned`, `dibuat` |
| 11 | `info_toko` | `id` (`TINYINT UNSIGNED`) | — | `CHECK (id = 1)` (1 baris tunggal); menyimpan nama toko, alamat, jam operasional, kontak, info pengambilan, dan rekening transfer opsional (`NULL` bila belum dikonfigurasi) |

### B. Urutan SQL untuk Database Baru
1. `backend/database/01_skema.sql`
2. `backend/database/03_role_warga.sql`
3. `backend/database/04_prosedur_pegawai.sql`
4. `backend/database/05_lowongan.sql`
5. `backend/database/06_pesanan.sql`
6. `backend/database/07_v3_fitur.sql` *(migrasi non-destruktif V3)*
7. `backend/database/08_seed_demo_v3.sql` *(opsional — seed demo V3)*
8. `backend/database/09_pemberhentian_pegawai.sql` *(status akun, alasan, & tanggal pemberhentian pegawai)*

### C. Akun Runtime Database
- **Aiven (Aktif di `backend/.env`):** 1 akun non-admin `rakrapi_app@%` (`REQUIRE SSL`, izin `SELECT, INSERT, UPDATE, DELETE ON rakrapi.*` + `EXECUTE ON PROCEDURE rakrapi.tambah_pegawai`, bukan `avnadmin`) dengan `DB_SSL=true` dan `DB_SSL_CA_BASE64`.
- **Database proyek lain di Aiven (`defaultdb`, `money_tracker`):** 100% terisolasi dan tidak diubah.

---

## 2. Dokumentasi REST API Lengkap (Base Path: `/api`)

Seluruh endpoint privat mewajibkan header `Authorization: Bearer <token>` (JWT HS256 berlaku 1 jam).

| Modul | Method & Path | Role Diizinkan | Fungsi & Status Respons |
|---|---|---|---|
| **Health** | `GET /api/health` | Publik | Cek kesiapan koneksi MySQL `rakrapi` (`200`, `503`) |
| **Auth** | `POST /api/auth/register` | Publik | Daftar akun baru; role dipaksa `warga` oleh server (`201`, `400`, `409`) |
| **Auth** | `POST /api/auth/login` | Publik | Login satu pintu 3 role; terbitkan JWT HS256 (`200`, `401`) |
| **Auth** | `GET /api/auth/me` | 3 role | Profil akun terkini dari MySQL (`200`, `401`) |
| **Auth** | `GET /api/auth/pemilik` | `pemilik` | Uji otorisasi khusus pemilik (`200`, `403`) |
| **Pegawai** | `GET /api/auth/pegawai` | `pemilik` | Daftar pegawai (mendukung `?status=aktif\|diberhentikan`) beserta status, alasan, dan tanggal pemberhentian (`200`, `403`) |
| **Pegawai** | `GET /api/auth/pegawai/:id` | `pemilik` | Detail 1 akun pegawai (`200`, `403`, `404`) |
| **Pegawai** | `POST /api/auth/pegawai` | `pemilik` | Buat akun pegawai baru (`201`, `400`, `403`, `409`) |
| **Pegawai** | `PATCH /api/auth/pegawai/:id/berhentikan` | `pemilik` | Berhentikan pegawai non-permanen (`{ alasan }`), cabut login & token JWT aktif, tolak target pemilik/warga (`200`, `400`, `403`, `404`, `409`) |
| **Kategori** | `GET /api/kategori` | 3 role | Daftar kategori + `jumlah_produk` via `LEFT JOIN` + `COUNT` (`200`) |
| **Kategori** | `GET /api/kategori/:id` | `pemilik` | Detail 1 kategori (`200`, `404`) |
| **Kategori** | `POST /api/kategori` | `pemilik` | Tambah kategori baru (`201`, `400`, `409`) |
| **Kategori** | `PATCH /api/kategori/:id` | `pemilik` | Ubah nama kategori (`200`, `400`, `404`, `409`) |
| **Kategori** | `DELETE /api/kategori/:id` | `pemilik` | Hapus kategori kosong; tolak `409` jika masih dipakai produk (`204`, `404`, `409`) |
| **Produk** | `GET /api/barang` | 3 role | Daftar produk `INNER JOIN kategori`; mendukung `?q=` dan `?kategori_id=` (`200`) |
| **Produk** | `GET /api/barang/:id` | 3 role | Detail produk lengkap + `deskripsi`, `tersedia`, `foto_url` (`200`, `404`) |
| **Produk** | `GET /api/barang/:id/foto` | 3 role | Ambil byte foto privat (JPG/PNG/WebP) dari Cloudinary/lokal (`200`, `404`) |
| **Produk** | `POST /api/barang` | `pemilik`, `pegawai` | Tambah produk + wajib upload foto multipart (`201`, `400`, `413`, `415`) |
| **Produk** | `PATCH /api/barang/:id` | `pemilik`, `pegawai` | Ubah data/stok/foto produk tanpa menimpa foto jika tidak diunggah (`200`, `400`, `409`) |
| **Produk** | `DELETE /api/barang/:id` | `pemilik` | Hapus produk + bersihkan foto yatim (`204`, `403`, `404`) |
| **Pesanan** | `POST /api/pesanan` | `warga` | Buat pesanan (`Ambil di kasir`, idempoten `kunci_kirim`, hitung ulang total `BigInt`, tolak transfer jika rekening belum diatur) (`201`, `400`, `409`) |
| **Pesanan** | `GET /api/pesanan` | 3 role | Daftar pesanan (warga: milik sendiri; toko: semua) beserta rincian item (`200`) |
| **Pesanan** | `GET /api/pesanan/:id` | 3 role | Detail pesanan & status pembayaran terpisah (warga lain ditolak `404`) (`200`, `404`) |
| **Pesanan** | `PATCH /api/pesanan/:id/konfirmasi` | `pemilik`, `pegawai` | Konfirmasi pesanan & kurangi stok atomik (`FOR UPDATE`) (`200`, `409`) |
| **Pesanan** | `PATCH /api/pesanan/:id/siap` | `pemilik`, `pegawai` | Ubah status `Dikonfirmasi` → `Siap diambil` (`200`, `409`) |
| **Pesanan** | `PATCH /api/pesanan/:id/bayar` | `pemilik`, `pegawai` | Verifikasi pembayaran manual (`Belum dibayar` → `Sudah dibayar`) (`200`, `403`, `409`) |
| **Pesanan** | `PATCH /api/pesanan/:id/selesai` | `pemilik`, `pegawai` | Selesaikan pesanan (wajib `Siap diambil` & `Sudah dibayar`) (`200`, `409`) |
| **Lowongan** | `GET /api/lowongan` & `/:id` & `/:id/foto` | 3 role | Daftar, detail, dan foto lowongan (warga: aktif saja) (`200`, `404`) |
| **Lowongan** | `POST/PATCH/DELETE /api/lowongan*` | `pemilik` | CRUD lowongan + foto opsional + `PATCH /:id/tutup` + `PATCH /:id/pin` (`200`/`201`/`204`) |
| **Lamaran** | `POST /api/lowongan/:id/lamar` | `warga` | Ajukan lamaran (tolak lowongan tutup/duplikat `409`) (`201`, `409`) |
| **Lamaran** | `GET /api/lowongan/lamaran/saya` | `warga` | Riwayat & status lamaran milik sendiri (`200`) |
| **Lamaran** | `GET /api/lowongan/lamaran` & `PATCH /:id` | `pemilik` | Daftar lamaran masuk & setujui/tolak (`200`, `400`, `409`) |
| **Bansos** | `GET /api/bansos` & `/:id` & `/:id/foto` | 3 role | Daftar/detail program bansos + `terpakai` & `sisa_kuota` (`200`, `404`) |
| **Bansos** | `POST/PATCH/DELETE /api/bansos*` | `pemilik` | CRUD program bansos + kuota + foto + `PATCH /:id/pin` (`200`/`201`/`204`) |
| **Pengajuan Bansos** | `POST /api/bansos/:id/ajukan` | `warga` | Kirim pengajuan bantuan (cek aktif, kuota, anti-duplikat) (`201`, `409`) |
| **Pengajuan Bansos** | `GET /api/bansos/pengajuan/saya` | `warga` | Status pengajuan bansos milik sendiri (`200`) |
| **Pengajuan Bansos** | `GET /api/bansos/pengajuan` & `PATCH /:id` | `pemilik` | Tinjau pengajuan (cek kuota transaksional saat menyetujui) (`200`, `409`) |
| **Pengumuman** | `GET /api/pengumuman` & `/:id` & `/:id/foto` | 3 role | Daftar/detail/foto pengumuman & diskon (`200`, `404`) |
| **Pengumuman** | `POST/PATCH/DELETE /api/pengumuman*` | `pemilik` | CRUD pengumuman/diskon + foto + `PATCH /:id/pin` (`200`/`201`/`204`) |
| **Pin Prioritas** | `GET /api/pin` | 3 role | Gabungan item terpin aktif (tanpa duplikasi data); pemilik mendukung `?semua=1` (`200`) |
| **Info Toko** | `GET /api/toko` | 3 role | Info toko + `rekening_tersedia` + detail bank bila dikonfigurasi (`200`) |
| **Info Toko** | `PATCH /api/toko` | `pemilik` | Perbarui info toko & rekening transfer opsional (`200`, `400`, `403`) |
| **Dashboard** | `GET /api/dashboard` | `pemilik`, `pegawai` | Statistik `COUNT(*)` aktual produk, kategori, pegawai, stok menipis, pesanan, pin, pengajuan (`200`, `403`) |

---

## 3. Panduan Menjalankan Aplikasi (Debugging Lokal & Emulator / HP)

### Backend (Terhubung ke MySQL Aiven + Cloudinary Privat)
```powershell
Set-Location C:\Users\Kaysan\UjiLevel\backend
npm.cmd run build
npm.cmd start
# Cek: curl.exe http://127.0.0.1:3000/api/health
```

### Android Emulator / HP USB (`adb reverse`)
```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s <ID_PERANGKAT> reverse tcp:3000 tcp:3000
Set-Location C:\Users\Kaysan\UjiLevel\frontend
flutter run -d <ID_PERANGKAT>
```
Untuk mengubah URL backend saat nanti memiliki backend publik HTTPS tanpa merombak source code:
```powershell
flutter build apk --release --dart-define=API_URL=https://domain-backend-anda/api
```
