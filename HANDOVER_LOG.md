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
- **Milestone sebelumnya:** `7650557` — `test: perketat validasi exp JWT, pesan sesi 401, dan uji autentikasi`
- **Milestone terbaru (Fase 3 Tahap 1–2):** Persiapan konfigurasi backend cloud Linux (`HOST`, CORS allowlist `CORS_ORIGIN`, `engines` Node `>=22.9.0 <23.0.0`, unit test CORS) + audit Aiven TLS & evaluasi validasi foto.

## 3. Keputusan Terbaru Pengembang (21 November 2026 — Fase 3)

1. **Prioritas utama:** RakRapi online All-Devices (Android APK + Website MAPIL) tanpa ketergantungan laptop, kabel USB, atau ADB Reverse. Konfigurasi development lokal tetap dipertahankan.
2. **Stack deployment yang disetujui:**
   - **Database online:** MySQL Aiven (`mysql-1067ea2a-mapiltugass.l.aivencloud.com:17374`).
   - **Hosting backend:** Render Free (`$0/bln`, Linux, HTTPS otomatis, Secret File `/etc/secrets/ca.pem`).
   - **Penyimpanan foto online:** Cloudinary Free (`$0/bln`, sesuai rekap materi guru *Intro Express JS*, mode autentikasi/privat; integrasi dikerjakan di Tahap 3 setelah keputusan validasi foto).
   - **Website MAPIL:** Flutter Web + Vercel (`$0/bln`, deployment final menunggu konfirmasi guru).
   - **Layanan berbayar / kartu pembayaran:** DILARANG tanpa persetujuan eksplisit.
3. **Batas perubahan Tahap 2:** Hanya `index.ts` (`HOST`), `app.ts` + `middleware/cors.middleware.ts` (`CORS_ORIGIN`), `package.json` (`engines` Node 22.x), `.env.example`, dan tes unit di `test/koneksi.cjs`. `koneksi.ts` dipertahankan tanpa perubahan karena Render Free mendukung Secret File.
4. **Validasi foto lintas OS (Tahap 3):** Penggantian validasi penuh `System.Drawing` dengan pemeriksaan header saja **BELUM disetujui**; menunggu keputusan opsi validasi lintas Linux/Windows sebelum memasang library atau mengubah `foto.validation.ts`.
5. **Migrasi Aiven (Tahap 4):** Menunggu pengisian kredensial Aiven privat oleh pengembang, hasil `periksa-aiven.cjs`, dan persetujuan migrasi.

## 4. Kondisi Aiven & Verifikasi TLS (21 November 2026)

- **Jangkauan TCP & MySQL handshake (baca-saja, tanpa login):** **TERJANGKAU & AKTIF**
  - Host/Port: `mysql-1067ea2a-mapiltugass.l.aivencloud.com:17374`
  - Versi server MySQL Aiven: `8.4.11` (protokol 10)
- **Verifikasi TLS terhadap `backend/private/aiven/ca.pem` (`rejectUnauthorized: true`):** **LULUS**
  - Protokol: `TLSv1.3`
  - CN sertifikat server: `mysql-1067ea2a-2` (berlaku hingga `Feb 3 09:52:49 2029 GMT`)
  - SHA-256 fingerprint: `83:1C:7F:A5:99:BF:C2:7D:F0:19:A5:7A:5F:4C:EB:B4:F1:E8:CC:DC:3E:DA:31:F0:8D:4D:71:AB:B5:59:7F:40`
- **Belum dapat diverifikasi (menunggu aksi pemilik akun):**
  - Status kredit trial & masa aktif paket Developer-1 di Aiven Console (`https://console.aiven.io`) hingga melewati 25 November 2026.
  - Daftar database/tabel dan izin `GRANT`/`CREATE PROCEDURE` pada `avnadmin` karena `ADMIN_DB_PASSWORD` (di `.env`) dan `DB_PASSWORD` (di `private/aiven/admin.env`) masih kosong.

## 5. Rencana Pencadangan Lokal Sebelum Migrasi

- Database Laragon lokal (`rakrapi`) **tidak boleh** dihapus atau di-reset.
- Sebelum migrasi Tahap 4, cadangkan ke folder `backend/private/` (sudah masuk `.gitignore`):
  1. Dump SQL penuh termasuk stored procedure: `mysqldump --login-path=rakrapi --host=127.0.0.1 --port=3306 --routines --single-transaction --databases rakrapi` → `backend/private/backup-laragon-YYYYMMDD.sql`.
  2. Salinan folder foto asli: `backend/private/uploads/db-rakrapi/` → `backend/private/backup-foto-YYYYMMDD/`.

## 6. Hasil Pengujian Terverifikasi (21 November 2026 — Pasca Tahap 2)

| Pengujian | Perintah | Hasil Aktual | Lingkungan |
|---|---|---|---|
| Handshake TCP & TLS Aiven | Node TLS probe read-only + `ca.pem` | **LULUS** — MySQL `8.4.11`, `TLSv1.3`, `tls_verified: true` | Aiven Cloud (tanpa login/tulis) |
| Build Backend | `npm.cmd run build` (`tsc`) | **LULUS** — exit code 0 | `backend/` |
| Tes Koneksi & CORS | `node --test test/koneksi.cjs` | **LULUS** — 6/6 tes lulus (termasuk allowlist CORS, preflight `OPTIONS` 204/403, tolak wildcard `*`) | Unit test (tanpa DB) |
| Tes Akun & JWT HTTP | `node --env-file=.env test/akun.cjs --uji-jwt` | **LULUS** — 90 cek JWT + register/pegawai/warga/lowongan lulus | DB uji terpisah sementara |
| Tes Katalog HTTP | `node --env-file=.env --test test/katalog.cjs` | **LULUS** — 5/5 tes lulus (CRUD kategori/barang, JOIN, 409, upload foto, restart) | DB uji terpisah sementara |
| Flutter Analyze & Test *(Tahap 1)* | `flutter analyze --no-pub` & `flutter test --no-pub` | **LULUS** — 0 issues, 18/18 tes lulus (frontend tidak diubah di Tahap 2) | `frontend/` |
| Integritas Data & Foto Asli | SHA-256 foto ID 2 | **UTUH** — `D731582FC79F60F0740122930E1FAABF116DE7CF487DB4E2336780BD7E968BF7` | `backend/private/uploads/db-rakrapi/` |

## 7. File yang Berubah pada Fase 3 Tahap 2

- `backend/src/index.ts` — dukungan `HOST` dari env (default lokal tetap `127.0.0.1`).
- `backend/src/middleware/cors.middleware.ts` — middleware CORS allowlist berbasis `CORS_ORIGIN` (tanpa wildcard `*`, dukung preflight `OPTIONS`, `Authorization`, `Content-Type`).
- `backend/src/app.ts` — memasang `aturCors` sebelum route API.
- `backend/package.json` — mengunci `engines.node` ke `>=22.9.0 <23.0.0` tanpa mengubah/upgrade dependency.
- `backend/.env.example` — mendokumentasikan `HOST` dan `CORS_ORIGIN`.
- `backend/test/koneksi.cjs` — menambah uji unit middleware CORS.
- `HANDOVER_LOG.md` — diperbarui dengan hasil audit Aiven & Tahap 2.

## 8. Langkah Berikutnya

1. **Pengembang mengisi password `avnadmin` secara privat** di `backend/private/aiven/admin.env` (`DB_PASSWORD=...`) dan mengecek status paket/kredit trial di Aiven Console.
2. **Jalankan inspeksi baca-saja Aiven** (`node --env-file=private/aiven/admin.env scripts/periksa-aiven.cjs`) serta uji izin `GRANT`/`CREATE PROCEDURE` sebelum menyetujui Tahap 4 (migrasi).
3. **Putuskan metode validasi foto lintas Windows/Linux** untuk Tahap 3 (sebelum mengintegrasikan Cloudinary di `foto.service.ts` dan menyentuh `foto.validation.ts`).
