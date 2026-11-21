# HANDOVER LOG — RAKRAPI (UJILEVEL)

> Catatan serah terima berkelanjutan (Codex → Gemini via Antigravity).
> **Aturan keamanan:** File ini tidak boleh berisi sandi, `JWT_SECRET`, token, API key, atau kredensial database.

## 1. Identitas Proyek

- **Aplikasi:** RakRapi — Digitalisasi UMKM Toko Sembako
- **Pengembang:** Muhammad Kaysan Ashraf (XI RPL 5 — SMK Taruna Bhakti, 2026/2027)
- **Mata pelajaran:** KOKE dan MAPIL
- **Deadline:** 25 November 2026
- **Workspace lokal:** `C:\Users\Kaysan\UjiLevel`
- **Repositori remote:** `https://github.com/kaysan2519/RakRapi.git`

## 2. Branch & Commit Aktual

- **Branch aktif:** `codex/ui-env-pixel8` *(tidak di-merge ke `main`, tidak force push)*
- **Riwayat milestone terakhir:**
  - `7650557` — `test: perketat validasi exp JWT, pesan sesi 401, dan uji autentikasi`
  - `52668ee` — `feat: siapkan konfigurasi HOST, CORS allowlist, dan versi Node untuk cloud`
  - Milestone terbaru (Fase 3 Tahap 3): Integrasi Cloudinary privat (`authenticated`), validasi foto lintas Windows/Linux Opsi V2 bersyarat (tanpa Sharp), backup lokal database & foto, dan pengujian keamanan upload (`test/foto.cjs`).

## 3. Keputusan Terbaru Pengembang (21 November 2026 — Fase 3 Lanjutan)

1. **Validasi foto lintas OS (Opsi V2 bersyarat):**
   - Menggunakan package `cloudinary` (`^2.11.0`), **tidak memasang `sharp`** dan tidak menambah dependency lain.
   - Mempertahankan validasi lokal Windows (`System.Drawing`) + menambah validasi struktur/dimensi PNG (`IHDR` + dekompresi `IDAT` via `node:zlib`) & JPEG (`SOF`/`SOS`) lintas OS (≤ 5 MiB, ≤ 16 MP, tolak MIME palsu & isi rusak) + validasi decode Cloudinary di production.
   - Keamanan Cloudinary tetap wajib dibuktikan lewat pengujian live setelah kredensial Cloudinary diisi secara privat.
2. **Penyimpanan foto online:** Cloudinary mode `authenticated` (privat), diambil server melalui signed download URL jangka pendek (60 detik) dan disajikan lewat endpoint existing `GET /api/barang/:id/foto` yang dilindungi JWT + role. Mode lokal tetap menjadi default development.
3. **Backup lokal:** Disetujui backup non-destruktif database Laragon dan foto asli ke `backend/private/` (diabaikan Git).
4. **Aiven & Deployment:** Migrasi production ke Aiven, deployment final Render, dan deployment final Flutter Web Vercel **belum diizinkan** sebelum hasil inspeksi Aiven (`periksa-aiven.cjs`), uji live Cloudinary, dan persetujuan berikutnya.

## 4. Kondisi Aiven & Status Permission (21 November 2026)

- **Jangkauan & TLS (`mysql-1067ea2a-mapiltugass.l.aivencloud.com:17374`):** Terjangkau (`MySQL 8.4.11`), handshake `TLSv1.3` terhadap `backend/private/aiven/ca.pem` lulus (`tls_verified: true`).
- **Login & Permission Aiven:** **BELUM DAPAT DIVERIFIKASI** karena `DB_PASSWORD` di `backend/private/aiven/admin.env` dan `ADMIN_DB_PASSWORD` di `backend/.env` masih kosong.
- **Tindakan yang dibutuhkan pengembang (privat, jangan kirim ke chat):**
  1. Cek status layanan *Running* & sisa kredit trial paket Developer-1 di `https://console.aiven.io`.
  2. Isi `DB_PASSWORD=` di `C:\Users\Kaysan\UjiLevel\backend\private\aiven\admin.env` (tidak mengubah `.env` Laragon).

## 5. Status Backup Lokal Non-Destruktif (Terverifikasi 21 November 2026)

- **Backup SQL:** `backend/private/backup-laragon-20261121.sql` (`9.250` byte, `mysqldump --routines --single-transaction --default-character-set=utf8mb4`, exit code `0`, UTF-8 valid tanpa null byte). Memuat 6 tabel (`users`, `kategori`, `barang`, `lowongan`, `pesanan`, `detail_pesanan`), 4 Foreign Key, stored procedure `tambah_pegawai`, serta data asli (`barang`, `kategori`, `users`).
- **Backup Foto:** `backend/private/backup-foto-20261121/431a9e84-3c42-438a-b876-a2f8816c61dd.png` — SHA-256 identik dengan file asli (`D731582FC79F60F0740122930E1FAABF116DE7CF487DB4E2336780BD7E968BF7`).
- **Keamanan Git:** Kedua backup berada di `backend/private/` yang diabaikan oleh `backend/.gitignore`.

## 6. Hasil Pengujian Terverifikasi (21 November 2026)

| Pengujian | Perintah | Hasil Aktual | Status |
|---|---|---|---|
| Build Backend | `npm.cmd run build` (`tsc`) | Exit code 0, 0 error | **LULUS** |
| Koneksi & CORS | `node --test test/koneksi.cjs` | 6/6 lulus (Laragon/Aiven TLS + allowlist CORS) | **LULUS** |
| Validasi Foto & Cloudinary (Terisolasi) | `node --test test/foto.cjs` | 4/4 suite lulus (PNG/JPEG valid, MIME palsu 415, >5 MiB 413, >16 MP PNG/JPEG 415, korup tengah 415, header valid isi IDAT rusak 415 Windows & Linux, Linux tanpa Cloudinary 503, gangguan Cloudinary 503, rollback aset yatim aman tanpa hapus foto asli) | **LULUS** *(uji live Cloudinary menunggu kredensial privat)* |
| Validasi Foto Asli ID 2 | `periksaFoto` read-only (`win32` & `linux`+Cloudinary) | `431a9e84-3c42-438a-b876-a2f8816c61dd.png` (`2.200.991` byte, `1254×1254`) lulus pada Windows & Linux | **LULUS** |
| Akun & JWT HTTP | `node --env-file=.env test/akun.cjs --uji-jwt` | Register/pegawai/warga/lowongan + 90 pemeriksaan HTTP/JWT lulus | **LULUS** |
| Katalog HTTP | `node --env-file=.env --test test/katalog.cjs` | 5/5 lulus (CRUD kategori/barang, JOIN, 409 RESTRICT, upload foto, restart) | **LULUS** |
| Integritas Data Asli | Read-only `SELECT` MySQL `rakrapi` + SHA-256 | `barang` ID 2 (`Minyak goreng 1 L`, Rp19.000, stok `12.000` botol), `kategori` ID 2, `users` (`pemilik:1, pegawai:1, warga:2`), foto SHA-256 identik | **UTUH** |

## 7. File yang Berubah pada Tahap Ini

- `backend/package.json` & `backend/package-lock.json` — menambah hanya `cloudinary` (`^2.11.0`, 0 kerentanan).
- `backend/src/validations/foto.validation.ts` — mempertahankan `System.Drawing` di Windows + menambah validasi struktur/dimensi PNG (`IHDR` + dekompresi `IDAT` via `node:zlib`) & JPEG (`SOF`/`SOS`) ≤ 16 MP lintas OS; menolak Linux tanpa Cloudinary (`503`).
- `backend/src/services/foto.service.ts` — mendukung penyimpanan privat `authenticated` Cloudinary (upload stream, verifikasi format/dimensi, private download URL 60 detik server-side, pembersihan aset yatim aman) sambil mempertahankan mode lokal untuk development & runner uji.
- `backend/.env.example` — menambah template variabel `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`.
- `backend/.env` *(lokal, diabaikan Git)* — menambahkan 3 baris kosong `CLOUDINARY_*` siap diisi privat.
- `backend/test/foto.cjs` — pengujian otomatis seluruh skenario validasi lintas OS & integrasi Cloudinary.
- `HANDOVER_LOG.md` — diperbarui.

## 8. Langkah Berikutnya

1. Pengembang mengisi kredensial secara privat (jangan dikirim ke chat):
   - Aiven `avnadmin`: `DB_PASSWORD=` di `backend/private/aiven/admin.env` (plus cek kredit trial di Aiven Console).
   - Cloudinary Free: `CLOUDINARY_CLOUD_NAME=`, `CLOUDINARY_API_KEY=`, `CLOUDINARY_API_SECRET=` di `backend/.env`.
2. Jalankan verifikasi live baca-saja Aiven (`periksa-aiven.cjs` + audit hak `GRANT`/`CREATE ROUTINE`) dan pengujian live Cloudinary pada folder uji terisolasi (termasuk uji nyata file PNG/JPEG valid & korup terhadap server Cloudinary).
3. Setelah hasil verifikasi Aiven & live Cloudinary disetujui, lanjut Tahap 4 (migrasi database Aiven) dan Tahap 5 (deploy backend Render Free).
