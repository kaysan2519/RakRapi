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
- **Milestone terverifikasi:**
  - `7650557` — `test: perketat validasi exp JWT, pesan sesi 401, dan uji autentikasi`
  - `52668ee` — `feat: siapkan konfigurasi HOST, CORS allowlist, dan versi Node untuk cloud`
  - `b4ca02b` — `feat: integrasikan Cloudinary privat dan validasi foto lintas OS (Opsi V2)`
  - `12b598b` — `docs: rapikan struktur satu env backend dan catat verifikasi live Aiven`
  - Milestone terbaru (Fase 4): Migrasi penuh database `rakrapi` ke Aiven (6 tabel + 4 FK + stored procedure + 4 akun minimal `REQUIRE SSL`), migrasi foto asli ID 2 ke Cloudinary privat (SHA-256 identik), pengujian JWT+Aiven+Cloudinary, dan bukti empiris validasi JPEG Pilihan 2.

## 3. Struktur Environment Aktif (Tetap 1 File Utama)

- `backend/.env` *(diabaikan Git)* — satu-satunya file konfigurasi aktif lokal (Laragon, `JWT_SECRET` tetap sama, `CLOUDINARY_*` terisi, `FOTO_STORAGE=lokal` agar dev lokal tetap memakai foto lokal).
- `backend/.env.example` *(tracked Git)* — template tanpa credential.
- `backend/private/aiven/` *(diabaikan Git, non-runtime)* — `ca.pem`, `admin.env` (admin migrasi), dan `kredensial-aplikasi.json` (4 akun aplikasi `REQUIRE SSL` untuk dimasukkan ke Dashboard Render, BUKAN `avnadmin`).
- `backend/private/arsip-env-20261122/` *(diabaikan Git)* — arsip file lama `.env.aiven`, `.env.demo`, `.env.sebelum-rapikan`.
- Tidak ada `.env.aiven`, `.env.demo`, atau `.env.production` di root `backend/`.

## 4. Hasil Migrasi Database Aiven & Foto Cloudinary (22 November 2026 — TERVERIFIKASI LIVE)

### A. Database Aiven (`mysql-1067ea2a-mapiltugass.l.aivencloud.com:17374`, MySQL `8.4.11`, `TLSv1.3`)
- **Database baru:** `rakrapi` (`utf8mb4` / `utf8mb4_0900_ai_ci`), diverifikasi `periksa-aiven.cjs` → `nama_database_drizzle: "rakrapi"`, `tls_terverifikasi: true`.
- **6 tabel terverifikasi:** `users`, `kategori`, `barang`, `lowongan`, `pesanan`, `detail_pesanan`.
- **4 Foreign Key terverifikasi:** `fk_barang_kategori`, `detail_pesanan_ibfk_1`, `detail_pesanan_ibfk_2`, `pesanan_ibfk_1`.
- **Stored procedure:** `tambah_pegawai` (`SECURITY_TYPE: DEFINER`, `DEFINER: avnadmin@%`) — diuji eksekusi `CALL tambah_pegawai` pada database uji terisolasi Aiven (kemudian dibersihkan), **LULUS**.
- **4 akun aplikasi minimal (`REQUIRE SSL`, bukan `avnadmin`):** `rakrapi_health@%`, `rakrapi_auth@%`, `rakrapi_pegawai@%`, `rakrapi_katalog@%` — `SHOW GRANTS` identik dengan Laragon.
- **Kesamaan data lokal vs Aiven (100% identik):**
  - `users`: 4 lokal = 4 Aiven (seluruh `password_hash` diverifikasi SHA-256 identik)
  - `kategori`: 1 lokal = 1 Aiven (`id=2`, `Minyak Goreng`)
  - `barang`: 1 lokal = 1 Aiven (`id=2`, `Minyak goreng 1 L`, `Rp19.000`, `12.000 botol`, `foto_key=431a9e84-3c42-438a-b876-a2f8816c61dd.png`)
  - `lowongan`: 0 = 0, `pesanan`: 0 = 0, `detail_pesanan`: 0 = 0
- **Keutuhan database proyek lain di Aiven (100% utuh):**
  - `defaultdb`: `notes=7`, `schema_migrations=2`, `users=3` (identik sebelum & sesudah)
  - `money_tracker`: `categories=14`, `transactions=2` (identik sebelum & sesudah)
- **Keutuhan lokal Laragon & backup:** Database Laragon `rakrapi` tetap aktif (`GET /api/health` → 200), backup SQL (`backup-laragon-20261121.sql`) & backup foto (`backup-foto-20261121`) utuh.

### B. Foto Asli ID 2 di Cloudinary Privat (`authenticated`)
- `foto_key`: `431a9e84-3c42-438a-b876-a2f8816c61dd.png` → `public_id`: `rakrapi/db-rakrapi/431a9e84-3c42-438a-b876-a2f8816c61dd`
- Ukuran & integritas: `2.200.991` byte lokal = `2.200.991` byte Cloudinary; **SHA-256 identik** (`D731582FC79F60F0740122930E1FAABF116DE7CF487DB4E2336780BD7E968BF7`).
- Keamanan privat: URL publik (`/image/upload/...`) → **HTTP 404**; URL `/image/authenticated/...` tanpa signature → **HTTP 401**. Foto lokal tetap utuh.

## 5. Hasil Pengujian Pasca-Migrasi (Backend Asli + Aiven + Cloudinary + JWT)

| Pengujian | Hasil Aktual | Status |
|---|---|---|
| Health API via Aiven TLS (`rakrapi_health`) | `GET /api/health` → HTTP 200 `{"status":"ok","nama_database":"rakrapi"}` | **LULUS** |
| Login `pemilik` & `pegawai` (`bcrypt.compare` + JWT HS256 1 jam) | HTTP 200, `exp - iat = 3600`, login sandi salah HTTP 401 | **LULUS** |
| Pemeriksaan role `warga` dari Aiven | `GET /api/auth/me` → HTTP 200 `role: warga` | **LULUS** |
| Token hilang/rusak/kedaluwarsa/tanpa `exp`/`none`/secret salah | **49/49 pemeriksaan HTTP 401** pada seluruh endpoint privat | **LULUS** |
| Hak akses 3 role (`pemilik`, `pegawai`, `warga`) | Pemilik `200`, pegawai/warga `403` sesuai matriks | **LULUS** |
| Katalog, Detail ID 2 (`INNER JOIN`), & Foto ID 2 via Cloudinary | Ketiga role HTTP 200; byte foto **SHA-256 identik** dengan foto asli | **LULUS** |
| Stored Procedure `tambah_pegawai` di Aiven (DB uji terisolasi) | `CALL tambah_pegawai` oleh akun `REQUIRE SSL` menghasilkan role `pegawai`; DB uji dibersihkan | **LULUS** |
| **Evaluasi Validasi JPEG Pilihan 2 (Cloudinary server-side decode)** | Uji live 3 metode Cloudinary (`eager_sync_png`, `colors+phash`, `quality_analysis`) pada `jpg_scan_korup` & `jpg_scan_kosong` → **ketiganya masih diterima Cloudinary (`DITERIMA_CLOUDINARY`, `eager_status: OK`)** karena decoder JPEG toleran mengisi area korup; `9/9` aset uji dibersihkan. | **GAGAL MENOLAK SCAN-KORUP — MENUNGGU KEPUTUSAN** |

## 6. Kendala & Keputusan Selanjutnya Sebelum Deployment Render (Tahap 5)

1. **Keputusan atas hasil Pilihan 2 (JPEG header valid + isi scan korup):**
   - Karena 3 metode decode Cloudinary tanpa dependency baru (`eager_sync_png`, `colors+phash`, `quality_analysis`) terbukti secara empiris **tidak menolak** JPEG scan-korup (sama seperti `System.Drawing` Windows), menunggu keputusan pengembang sebelum deployment Render:
     - **Opsi A:** Menerima batas kasus ekstrem JPEG scan-korup pada Opsi V2 (tanpa tambah dependency di luar materi guru; PNG IDAT rusak tetap tertolak `415`, JPEG sampah/MIME palsu/>5 MiB/>16 MP tetap tertolak `413`/`415`, plus boleh tambah 3 baris penolakan `jpg_scan_kosong` di `dimensiJpeg`) → langsung lanjut deploy Render Free (Tahap 5).
     - **Opsi B:** Menyetujui pemasangan `sharp` (`failOn: 'error'`) khusus untuk menolak JPEG scan-korup secara ketat di Linux & Windows sebelum deploy Render.
2. **Konfirmasi status kredit trial Aiven** hingga melewati **25 November 2026** dan persetujuan mulai **Tahap 5 (Deploy Backend Render Free)**.
