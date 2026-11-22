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

## 2. Branch, Checkpoint, & Commit Aktual

- **Branch aktif:** `codex/ui-env-pixel8` *(tidak di-merge ke `main`, tidak force push)*
- **Checkpoint sebelum simplifikasi:** tag `checkpoint/sebelum-simplifikasi-33b641a` pada commit `33b641a`
- **Riwayat milestone terverifikasi:**
  - `7650557` — `test: perketat validasi exp JWT, pesan sesi 401, dan uji autentikasi`
  - `52668ee` — `feat: siapkan konfigurasi HOST, CORS allowlist, dan versi Node untuk cloud`
  - `b4ca02b` — `feat: integrasikan Cloudinary privat dan validasi foto lintas OS (Opsi V2)`
  - `12b598b` — `docs: rapikan struktur satu env backend dan catat verifikasi live Aiven`
  - `0e61c02` — `docs: catat hasil migrasi Aiven, foto Cloudinary privat, dan evaluasi validasi JPEG`
  - `33b641a` — `feat(backend): validasi foto PNG/JPEG ketat menggunakan Sharp`
  - **Simplifikasi terbaru (22 November 2026):** Penyatuan menjadi **1 file `.env` sederhana (struktur MyNotes)**, **1 pool Drizzle ORM (`db`)**, **1 akun runtime aplikasi (`rakrapi_app`)** pada Laragon dan Aiven (`REQUIRE SSL`, bukan `avnadmin`), penyederhanaan `foto.service.ts` (Cloudinary privat tanpa `GET_LOCK`/mock, turun dari 325 → 176 baris), penyederhanaan `koneksi.ts` (`DB_SSL` + `DB_SSL_CA_BASE64`), `akun.service.ts` (`JWT_EXPIRES_IN=1h`, `BCRYPT_SALT_ROUNDS=12`), `cors.middleware.ts`, pembersihan total Render (API key terverifikasi `HTTP 401` dan dihapus), serta sinkronisasi SRS, diagram, blackbox testing, dan panduan presentasi ujian.

  - **Penyempurnaan Prototype V3 (22 November 2026):** Checkpoint tag `checkpoint/sebelum-v3-a93c42b` & backup lokal Laragon/Aiven; migrasi non-destruktif `07_v3_fitur.sql` (6 tabel inti → 11 tabel, 8 FK, 9 satuan produk, status pesanan & pembayaran terpisah, lowongan+lamaran, bansos+kuota, pengumuman/diskon, pin `is_pinned` tanpa duplikasi, `info_toko` & rekening opsional); seed idempoten `08_seed_demo_v3.sql` pada Aiven & Laragon (10 kategori, 18 produk, 3 lowongan, 2 bansos, 4 pengumuman, 18 aset foto PNG di Cloudinary privat; produk asli ID 2 utuh); REST API V3 lengkap + cache foto privat; seluruh UI/UX Flutter V3 (Login/Register satu pintu tanpa pilih role, Beranda Pembeli + info toko atas + Info Prioritas, Katalog cari/filter, Keranjang & Checkout `Ambil di kasir` + Bayar di kasir/Transfer terproteksi, Dashboard Pemilik dengan tombol atas `Pin informasi ke beranda`, Dashboard Pegawai); lulus 12/12 suite uji backend V3, 20/20 `flutter test`, `flutter analyze` 0 issue, E2E emulator `Pixel_8` live Aiven+Cloudinary (8 screenshot aktual), Release APK `51,4 MB`, dan sinkronisasi penuh SRS/Diagram/API/Panduan Presentasi.

## 3. Struktur Environment Aktif (1 File Utama — Struktur MyNotes)

- `backend/.env` *(diabaikan Git)* — satu-satunya file konfigurasi aktif (16 variabel: `NODE_ENV`, `PORT`, `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_SSL`, `DB_SSL_CA_BASE64`, `JWT_SECRET`, `JWT_EXPIRES_IN`, `BCRYPT_SALT_ROUNDS`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, `CORS_ORIGIN`).
- `backend/.env.example` *(tracked Git)* — template tanpa nilai rahasia.
- `backend/private/aiven/` *(diabaikan Git, non-runtime)* — `ca.pem`, `admin.env`, `kredensial-aplikasi.json`, `kredensial-app-tunggal.json` (`rakrapi_app@%` + `DB_SSL_CA_BASE64`).
- `backend/private/arsip-env-20261122/` *(diabaikan Git)* — cadangan `.env` lama sebelum dirapikan dan sebelum simplifikasi.
- Tidak ada file Render API key maupun script Render tersisa.

## 4. Hasil Pengujian Pasca-Simplifikasi (22 November 2026 — TERVERIFIKASI LIVE)

| Pengujian | Hasil Aktual | Status |
|---|---|---|
| Backend TypeScript build (`npm run build`) | Exit code 0, 0 error | **LULUS** |
| Flutter analyze (`flutter analyze --no-pub`) | `No issues found!` | **LULUS** |
| Flutter tests (`flutter test --no-pub`) | **18/18 tes lulus** (`sesi_test`, `keranjang_test`, `form_barang_test`, `tampilan_test`) | **LULUS** |
| Unit koneksi, TLS base64, & CORS (`test/koneksi.cjs`) | 4/4 tes lulus | **LULUS** |
| Unit validasi Sharp & foto (`test/foto.cjs`) | 4/4 tes lulus (PNG/JPEG/corrupt/MIME/>5MiB/>16MP + foto ID 2) | **LULUS** |
| Akun, 3 role, lowongan, & JWT (`test/akun.cjs --uji-jwt`) | **90/90 pemeriksaan HTTP JWT lulus** (`HS256`, 3600 detik, role live dari MySQL) | **LULUS** |
| Keranjang, pesanan, konfirmasi, & transaksi stok (`test/akun.cjs --uji-pesanan`) | Konfirmasi serentak, stok 14→12 & 12.5→10, stok kurang 409 rollback utuh, harga lama terjaga | **LULUS** |
| Katalog, CRUD kategori/barang, `INNER JOIN`, FK 409, upload foto (`test/katalog.cjs`) | 5/5 subtest lulus | **LULUS** |
| Live Laragon (`rakrapi_app@localhost`, 1 pool `db` + Cloudinary privat) | Health 200, login 3 role 200/401/403, detail ID 2, foto ID 2 SHA-256 identik, CORS 204 | **LULUS** |
| Live Aiven (`rakrapi_app@%`, `DB_SSL=true`, `DB_SSL_CA_BASE64`, `TLSv1.3` + Cloudinary privat) | Health 200, `periksa-aiven.cjs` TLS terverifikasi, login 3 role, detail ID 2, foto ID 2 SHA-256 identik | **LULUS** |
| Integritas Data Asli, Backup, Stored Procedure, & Proyek Aiven Lain | `users=4`, `kategori=1`, `barang=1` (ID 2 Rp19.000, 12 botol), `defaultdb` & `money_tracker` utuh, `tambah_pegawai` utuh, 4 akun lama + `rakrapi_app` utuh, SHA-256 foto identik | **LULUS** |
| Konkurensi Foto & Transaksi (`uji_konkurensi_akhir.cjs`, DB uji terisolasi) | 10/10 baca foto paralel 200 identik; edit harga + 6/6 baca foto 200 identik; ganti foto A→B + 8 baca paralel (`0` korup, `0` race 404, 1 file akhir fotoB); 3 kirim pesanan identik → 1 baris DB; 3 konfirmasi serentak → stok 10→7 tepat sekali | **LULUS** |
| Build Android Release APK (`flutter build apk --release`) | `frontend/build/app/outputs/flutter-apk/app-release.apk` terbentuk (**50,38 MB**, SHA-256 `42C7853212850B5C0378DCE672A608C188AEA5AE51318AA4FE974E2AA6F84929`, default `http://127.0.0.1:3000/api`) | **LULUS** |

## 5. Bagian yang Belum Selesai / Belum Terverifikasi (Jujur & Transparan)

1. **Verifikasi isi Google Docs *Intro Express JS*:** Dokumen terkunci login Google dan belum tersedia di folder `docs/`, sehingga kesesuaian detail contoh kode guru untuk (a) pengganti `sharp` pada validasi upload gambar (`foto.validation.ts` dipertahankan sementara agar keamanan validasi tidak melemah) dan (b) pola persis Cloudinary/Drizzle di dokumen guru belum dapat diverifikasi baris per baris.
2. **Deployment Website MAPIL (Vercel/Netlify) & Jalur Backend Publik (All Devices):** Deployment Render dihentikan total sesuai keputusan pengembang. Bentuk website MAPIL dan jalur hosting backend publik sesuai materi guru menunggu konfirmasi guru dan keputusan pengembang (tanpa memilih layanan alternatif sepihak).
