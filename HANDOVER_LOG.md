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

## 4. Kondisi Aiven & Status Permission (TERVERIFIKASI LIVE — 22 November 2026 07:47)

- **Login & TLS (`periksa-aiven.cjs` & `audit_aiven_readonly.cjs`):** **LULUS 100%**
  - Host & Port: `mysql-1067ea2a-mapiltugass.l.aivencloud.com:17374`
  - Akun admin aktif: `avnadmin@%` · Versi MySQL: **`8.4.11`**
  - TLS: `tls_terenkripsi: true`, `tls_terverifikasi: true`, protokol **`TLSv1.3`**, sidik sertifikat `83:1C:7F:A5:99:BF:C2:7D:F0:19:A5:7A:5F:4C:EB:B4:F1:E8:CC:DC:3E:DA:31:F0:8D:4D:71:AB:B5:59:7F:40`
- **Database existing pada layanan Aiven (TIDAK BOLEH DISENTUH):**
  - `defaultdb`: `notes`, `schema_migrations`, `users`
  - `money_tracker`: `categories`, `transactions`
  - **Database `rakrapi` belum ada** (`nama_database_drizzle: null`) — aman dibuat terpisah tanpa benturan dengan proyek lain.
- **Permission & Variabel Server Aiven (100% kompatibel dengan RakRapi):**
  - `avnadmin@%` memiliki `CREATE`, `CREATE ROUTINE`, `ALTER ROUTINE`, `EXECUTE`, `CREATE USER`, dan `WITH GRANT OPTION` (mendukung stored procedure `tambah_pegawai` dan pembuatan 4 akun aplikasi terpisah tanpa memakai admin sebagai akun API!).
  - `log_bin_trust_function_creators = ON`, `sql_require_primary_key = ON` (semua 6 tabel RakRapi ber-PK), `character_set_server = utf8mb4`, `collation_server = utf8mb4_0900_ai_ci`, `lower_case_table_names = 0` (semua nama tabel RakRapi huruf kecil), `sql_mode` memakai `ANSI_QUOTES` (semua SQL RakRapi memakai tanda petik tunggal).
- **Kredensial privat:** Password `avnadmin` tersimpan aman di `backend/private/aiven/admin.env` (diabaikan Git), clipboard sudah dikosongkan (`CLIPBOARD_CLEARED=True`). Status sisa kredit trial Developer-1 tetap perlu dikonfirmasi dari Billing Aiven Console.
- **Status Cloudinary:** Menunggu salinan `CLOUDINARY_URL` via clipboard untuk mengisi `backend/.env` baris 27–29 dan menjalankan 11 pengujian live Cloudinary.

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

## 7. Struktur Environment Terbaru & File yang Berubah (22 November 2026)

- **Struktur aktif di `backend/` (disederhanakan menjadi 1 file aktif + 1 template):**
  - `backend/.env` *(diabaikan Git)* — satu-satunya file konfigurasi aktif lokal (24 variabel terstruktur: Laragon/Aiven `DB_MODE`, `HOST`, `PORT`, `CORS_ORIGIN`, 4 akun DB terpisah, `JWT_SECRET` tidak berubah, placeholder `CLOUDINARY_*`, sandi uji demo).
  - `backend/.env.example` *(tracked Git)* — template tanpa credential + catatan deployment Render Dashboard.
  - `backend/private/aiven/admin.env` *(diabaikan Git, terpisah sementara)* — kredensial admin Aiven khusus inspeksi & migrasi Tahap 4 (tidak dipakai runtime API).
  - `backend/private/arsip-env-20261122/` *(diabaikan Git)* — arsip aman file lama `.env.aiven`, `.env.demo`, dan `.env.sebelum-rapikan`.
- **Production di Render:** Menggunakan *Environment Variables* pada Dashboard Render + *Secret File* `/etc/secrets/ca.pem` (tidak mengunggah `.env`).
- **File tracked yang berubah pada perapian env:** `backend/.env.example`, `backend/README.md`, `HANDOVER_LOG.md`. **0 perubahan source code.**

## 8. Langkah Berikutnya

1. Salin `CLOUDINARY_URL` di Cloudinary Console (1 klik Copy, ketik manual **`ok cloudinary`**) untuk mengisi baris `CLOUDINARY_*` di `backend/.env` secara aman dan menjalankan 11 pengujian live Cloudinary.
2. Setelah uji live Cloudinary lulus dan disetujui, minta persetujuan Tahap 4 (migrasi database Aiven — membuat database `rakrapi` terpisah, 6 tabel + FK + stored procedure `tambah_pegawai`, 4 akun aplikasi `REQUIRE SSL`, migrasi data asli + unggah foto asli ID 2 ke Cloudinary).
3. Lanjut Tahap 5 (deploy backend Render Free via Dashboard Env Vars + Secret File `ca.pem`), Tahap 6 (build APK All-Devices), dan Tahap 7 (Flutter Web + Vercel setelah konfirmasi guru).
