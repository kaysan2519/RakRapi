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

  - **Sistem Pemberhentian Pegawai (`bd5af8f`, 22 November 2026):** Migrasi non-destruktif `09_pemberhentian_pegawai.sql` (`users.status`, `alasan_pemberhentian`, `diberhentikan_pada`), endpoint `GET /api/auth/pegawai/:id` & `PATCH /api/auth/pegawai/:id/berhentikan`, penolakan login `403` dan pencabutan JWT aktif seketika `401` di `akses.middleware.ts`, tab `Aktif`/`Diberhentikan` & detail pegawai di `pengelolaan_toko.dart`.
  - **Audit Kepatuhan Menyeluruh & Penghapusan `sharp` (22 November 2026):** Checkpoint tag `checkpoint/sebelum-audit-sharp-bd5af8f` pada `bd5af8f`; verifikasi langsung Google Docs *Intro Express js* (publik view-only, 5 tab), 19 artikel `divdannn.medium.com`, soal resmi KOKE & MAPIL, serta materi basis data/ERD lokal; penghapusan penuh library `sharp` & native `@img/*`/`libvips` (`npm ls sharp` kosong, `package-lock.json` 0 referensi); penggantian validasi foto di `foto.validation.ts` memakai modul bawaan Node.js (`Buffer` + `node:zlib` `crc32`) untuk JPG/PNG/WebP (≤ 5 MiB, ≤ 16 MP) + pemetaan HTTP `400` Cloudinary ke `415` di `foto.service.ts`; lulus seluruh regresi pasca-penghapusan Sharp (`test/koneksi.cjs` 4/4, `test/foto.cjs` 4/4, `test/jwt.cjs` 90/90 HTTP, `uji_backend_v3.cjs` 13/13, live Aiven + Cloudinary ID 2/9/13, `flutter analyze` 0 issue, `flutter test` 21/21, Release APK `51,5 MB`, smoke test `Pixel_8`, DB sebelum==sesudah identik).

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
| Unit validasi biner foto tanpa Sharp (`test/foto.cjs`) | 4/4 tes lulus (PNG/JPEG/WebP/kosong/corrupt/format tak didukung/MIME palsu/menyamar/>5MiB/>16MP + aset WebP + foto ID 2) | **LULUS** |
| Akun, 3 role, lowongan, & JWT (`test/akun.cjs --uji-jwt`) | **90/90 pemeriksaan HTTP JWT lulus** (`HS256`, 3600 detik, role live dari MySQL) | **LULUS** |
| Keranjang, pesanan, konfirmasi, & transaksi stok (`test/akun.cjs --uji-pesanan`) | Konfirmasi serentak, stok 14→12 & 12.5→10, stok kurang 409 rollback utuh, harga lama terjaga | **LULUS** |
| Katalog, CRUD kategori/barang, `INNER JOIN`, FK 409, upload foto (`test/katalog.cjs`) | 5/5 subtest lulus | **LULUS** |
| Live Laragon (`rakrapi_app@localhost`, 1 pool `db` + Cloudinary privat) | Health 200, login 3 role 200/401/403, detail ID 2, foto ID 2 SHA-256 identik, CORS 204 | **LULUS** |
| Live Aiven (`rakrapi_app@%`, `DB_SSL=true`, `DB_SSL_CA_BASE64`, `TLSv1.3` + Cloudinary privat) | Health 200, `periksa-aiven.cjs` TLS terverifikasi, login 3 role, detail ID 2, foto ID 2 SHA-256 identik | **LULUS** |
| Integritas Data Asli, Backup, Stored Procedure, & Proyek Aiven Lain | `users=4`, `kategori=1`, `barang=1` (ID 2 Rp19.000, 12 botol), `defaultdb` & `money_tracker` utuh, `tambah_pegawai` utuh, 4 akun lama + `rakrapi_app` utuh, SHA-256 foto identik | **LULUS** |
| Konkurensi Foto & Transaksi (`uji_konkurensi_akhir.cjs`, DB uji terisolasi) | 10/10 baca foto paralel 200 identik; edit harga + 6/6 baca foto 200 identik; ganti foto A→B + 8 baca paralel (`0` korup, `0` race 404, 1 file akhir fotoB); 3 kirim pesanan identik → 1 baris DB; 3 konfirmasi serentak → stok 10→7 tepat sekali | **LULUS** |
| Build Android Release APK (`flutter build apk --release`) | `frontend/build/app/outputs/flutter-apk/app-release.apk` terbentuk (**50,38 MB**, SHA-256 `42C7853212850B5C0378DCE672A608C188AEA5AE51318AA4FE974E2AA6F84929`, default `http://127.0.0.1:3000/api`) | **LULUS** |

## 5. Bagian yang Belum Selesai / Membutuhkan Keputusan (Jujur & Transparan)

1. **Deployment Website MAPIL (Vercel/Netlify) & Jalur Backend Publik:** Soal MAPIL mensyaratkan deployment website ke Vercel/Netlify beserta dokumentasinya (database Aiven sudah selesai). Deployment Render dihentikan total sesuai keputusan pengembang; bentuk website MAPIL dan jalur hosting backend publik menunggu keputusan pengembang.
2. **Penggantian Data Demo Menjadi Data Operasional Asli:** 15 produk seed demo, 3 lowongan, 2 program bansos, 4 pengumuman, serta alamat/kontak/rekening toko pada `info_toko` masih mempertahankan kondisi saat ini (tanpa mengarang data asli) dan menunggu konfirmasi pengembang.
3. **Pengujian Interaktif HP Fisik (`SM_S731B` / `RRCY901YB5F`):** Perangkat terdeteksi via ADB dan `com.example.rakrapi` terpasang, namun pengujian UI interaktif penuh hanya dijalankan pada emulator `Pixel_8` (`emulator-5554`) agar tidak mengganggu layar HP fisik pengembang.
