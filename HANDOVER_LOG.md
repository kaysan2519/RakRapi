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
  - **Audit Kepatuhan Menyeluruh & Penghapusan `sharp` (`8411fef`, 22 November 2026):** Checkpoint tag `checkpoint/sebelum-audit-sharp-bd5af8f` pada `bd5af8f`; verifikasi langsung Google Docs *Intro Express js* (publik view-only, 5 tab), 19 artikel `divdannn.medium.com`, soal resmi KOKE & MAPIL, serta materi basis data/ERD lokal; penghapusan penuh library `sharp` & native `@img/*`/`libvips` (`npm ls sharp` kosong, `package-lock.json` 0 referensi); penggantian validasi foto di `foto.validation.ts` memakai modul bawaan Node.js (`Buffer` + `node:zlib` `crc32`) untuk JPG/PNG/WebP (≤ 5 MiB, ≤ 16 MP) + pemetaan HTTP `400` Cloudinary ke `415` di `foto.service.ts`; lulus seluruh regresi pasca-penghapusan Sharp.
  - **Finalisasi Data Operasional & Foto Produk Nyata (22 November 2026):** Backup penuh Aiven sebelum perubahan (`backend/private/backup-aiven-sebelum-finalisasi-data.json`, gitignored); pembaruan non-destruktif 15 produk + penambahan 2 produk pelengkap (`Minyak Goreng Bimoli Pouch 2 L`, `Sunlight Jeruk Nipis 650 ml`) → total **20 produk aktif di 10 kategori** (masing-masing 2 produk) dengan nama merek & kisaran harga referensi pasar Indonesia Depok/Jabodetabek, **3 produk & foto asli (ID 2, ID 9, ID 13) 100% utuh**; penggantian seluruh foto placeholder dengan foto nyata berlisensi terbuka/resmi (**30/30 foto Cloudinary privat HTTP 200** dan lulus `periksaFoto()` tanpa Sharp); finalisasi 3 lowongan (`Staff Toko`, `Kasir`, `Petugas Gudang`), 3 program bansos berkuota (tanpa NIK/data pribadi fiktif, status simulasi UMKM jelas), 4 pengumuman/promo (konsisten katalog), dan `info_toko` (rekening transfer tetap dinonaktifkan, tanpa nomor telepon/rekening fiktif); **0 tulisan `(Demo)`/placeholder** di seluruh aplikasi; seluruh akun (`5`), riwayat pesanan (`1`), detail pesanan (`barang_id=15`), lamaran (`lowongan_id=3`), 11 tabel, 8 FK, serta `defaultdb` & `money_tracker` 100% utuh; 8 tangkapan layar aktual `Pixel_8` terbaru (`docs/bukti/v3-pixel8/01..08.png`) & seluruh dokumen disinkronkan.

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
| Flutter tests (`flutter test --no-pub`) | **21/21 tes lulus** (`sesi_test`, `keranjang_test`, `form_barang_test`, `tampilan_test`) | **LULUS** |
| Unit koneksi, TLS base64, & CORS (`test/koneksi.cjs`) | 4/4 tes lulus | **LULUS** |
| Unit validasi biner foto tanpa Sharp (`test/foto.cjs`) | 4/4 tes lulus (PNG/JPEG/WebP/kosong/corrupt/format tak didukung/MIME palsu/menyamar/>5MiB/>16MP + aset WebP + foto ID 2) | **LULUS** |
| Akun, 3 role, lowongan, & JWT (`test/akun.cjs --uji-jwt`) | **90/90 pemeriksaan HTTP JWT lulus** (`HS256`, 3600 detik, role live dari MySQL) | **LULUS** |
| Suite V3 & Pemberhentian Pegawai (`uji_backend_v3.cjs`) | **13/13 suite lulus** (termasuk pemberhentian pegawai non-permanen, cabut JWT 401, login 403, transaksi stok, bansos kuota, pin) | **LULUS** |
| Live Aiven (`rakrapi_app@%`, `TLSv1.3`) + Cloudinary privat | 10 kategori (masing-masing 2 produk), **20 produk**, 3 lowongan, 3 bansos, 4 pengumuman, 1 `info_toko`; **30/30 foto HTTP 200**; **0 tulisan `(Demo)`**; ID 2 (`2.200.991` B, SHA-256 identik), ID 9, ID 13, 5 akun, pesanan #1, lamaran #1, 11 tabel, 8 FK, `defaultdb` & `money_tracker` 100% utuh | **LULUS** |
| E2E Emulator `Pixel_8` (`v3_emulator_bukti_test.dart`) | 8 tangkapan layar aktual terbaru (`docs/bukti/v3-pixel8/01..08.png`) terverifikasi visual tanpa error/overflow/label Demo | **LULUS** |
| Build Android Release APK (`flutter build apk --release`) | `frontend/build/app/outputs/flutter-apk/app-release.apk` terbentuk bersih tanpa plugin `integration_test` | **LULUS** |

## 5. Bagian yang Belum Selesai / Membutuhkan Keputusan (Jujur & Transparan)

1. **Deployment Website MAPIL (Vercel/Netlify) & Jalur Backend Publik:** Soal MAPIL mensyaratkan deployment website ke Vercel/Netlify beserta dokumentasinya (database Aiven sudah selesai). Deployment Render dihentikan total sesuai keputusan pengembang; bentuk website MAPIL dan jalur hosting backend publik menunggu keputusan pengembang.
2. **Pengujian Interaktif HP Fisik (`SM_S731B` / `RRCY901YB5F`):** Perangkat terdeteksi via ADB dan `com.example.rakrapi` terpasang, namun pengujian UI interaktif penuh hanya dijalankan pada emulator `Pixel_8` (`emulator-5554`) agar tidak mengganggu layar HP fisik pengembang.
3. **Status Data Simulasi UMKM:** Stok barang, skenario 3 lowongan, 3 program bansos (bukan program pemerintah & tanpa NIK/data pribadi fiktif), promo kasir, serta alamat/kontak layanan kasir di `info_toko` (transfer bank dinonaktifkan karena rekening resmi belum tersedia) merupakan skenario operasional proyek simulasi UMKM Uji Level yang terdokumentasi transparan.
