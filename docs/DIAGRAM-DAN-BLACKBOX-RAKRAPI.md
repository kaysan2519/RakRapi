# Diagram Sistem dan Pengujian Blackbox — RakRapi

> **Disinkronkan dengan implementasi akhir:** 22 November 2026 (`codex/ui-env-pixel8`)  
> **Pengembang:** Muhammad Kaysan Ashraf — XI RPL 5 — SMK Taruna Bhakti (Uji Level KOKE & MAPIL 2026/2027)  
> **Arsitektur aktif:** Flutter (Android) → REST API Express.js + TypeScript + Drizzle ORM (1 pool `db`, 1 file `.env`, JWT HS256 1 jam, `bcryptjs`, Cloudinary privat) → MySQL 8 (Laragon lokal & Aiven `TLSv1.3`).

---

## 1. Entity Relationship Diagram (ERD — 6 Tabel & 4 Foreign Key)

Lampiran gambar ERD lengkap: [erd-rakrapi-lengkap.png](bukti/erd-rakrapi-lengkap.png).

```mermaid
erDiagram
    users {
        INT id PK "AUTO_INCREMENT UNSIGNED"
        VARCHAR nama "NOT NULL (100)"
        VARCHAR email UK "NOT NULL UNIQUE (255)"
        VARCHAR password_hash "NOT NULL (255, bcryptjs)"
        VARCHAR role "NOT NULL DEFAULT warga (pemilik|pegawai|warga)"
    }

    kategori {
        INT id PK "AUTO_INCREMENT UNSIGNED"
        VARCHAR nama UK "NOT NULL UNIQUE (100)"
    }

    barang {
        INT id PK "AUTO_INCREMENT UNSIGNED"
        INT kategori_id FK "NOT NULL -> kategori.id (ON DELETE RESTRICT)"
        VARCHAR nama "NOT NULL (150)"
        INT harga_rupiah "NOT NULL UNSIGNED"
        DECIMAL stok "NOT NULL (12,3; botol bulat, kg maks 3 desimal)"
        VARCHAR satuan "NOT NULL (botol|kg)"
        VARCHAR foto_key "NOT NULL (255, UUID.png / UUID.jpg)"
    }

    lowongan {
        INT id PK "AUTO_INCREMENT UNSIGNED"
        VARCHAR judul "NOT NULL (150)"
        BOOLEAN aktif "NOT NULL DEFAULT true"
    }

    pesanan {
        INT id PK "AUTO_INCREMENT UNSIGNED"
        INT warga_id FK "NOT NULL -> users.id (ON DELETE RESTRICT)"
        VARCHAR nama_pemesan "NOT NULL (100)"
        CHAR kunci_kirim UK "NOT NULL (32, UNIQUE bersama warga_id)"
        ENUM status "Menunggu konfirmasi | Dikonfirmasi"
        DECIMAL total_rupiah "NOT NULL (32,0)"
        DATETIME dibuat "NOT NULL DEFAULT CURRENT_TIMESTAMP"
    }

    detail_pesanan {
        INT id PK "AUTO_INCREMENT UNSIGNED"
        INT pesanan_id FK "NOT NULL -> pesanan.id (ON DELETE CASCADE)"
        INT barang_id FK "NULL -> barang.id (ON DELETE SET NULL)"
        VARCHAR nama_barang "NOT NULL (150)"
        VARCHAR satuan "NOT NULL (20)"
        DECIMAL jumlah "NOT NULL (12,3)"
        INT harga_rupiah "NOT NULL UNSIGNED"
    }

    kategori ||--o{ barang : "memiliki (fk_barang_kategori)"
    users ||--o{ pesanan : "membuat (pesanan_ibfk_1)"
    pesanan ||--|{ detail_pesanan : "memuat (detail_pesanan_ibfk_1)"
    barang ||--o{ detail_pesanan : "dirujuk (detail_pesanan_ibfk_2)"
```

> **Catatan Database:** Stored procedure `tambah_pegawai` tetap dipertahankan pada database Laragon dan Aiven (`04_prosedur_pegawai.sql`) sampai verifikasi materi Basis Data selesai.

---

## 2. Use Case Diagram (4 Aktor & Pembatasan Role JWT)

```mermaid
flowchart LR
    Pengunjung["Pengunjung"]
    Warga["Warga (role: warga)"]
    Pegawai["Pegawai (role: pegawai)"]
    Pemilik["Pemilik Toko (role: pemilik)"]

    subgraph RakRapi["Sistem RakRapi (REST API + Flutter)"]
        UC1["Daftar Akun Warga (POST /api/auth/register)"]
        UC2["Masuk / Login JWT HS256 (POST /api/auth/login)"]
        UC3["Lihat Katalog, Detail & Foto Privat (GET /api/barang*)"]
        UC4["Kelola Keranjang & Kirim Pesanan (POST /api/pesanan)"]
        UC5["Lihat Pesanan Saya (GET /api/pesanan)"]
        UC6["Lihat Lowongan Aktif & Tab Bansos (GET /api/lowongan)"]
        UC7["Tambah & Ubah Barang + Upload Foto (POST/PATCH /api/barang)"]
        UC8["Lihat & Konfirmasi Pesanan Masuk (PATCH /api/pesanan/:id/konfirmasi)"]
        UC9["Kelola Kategori CRUD (GET/POST/PATCH/DELETE /api/kategori)"]
        UC10["Hapus Barang (DELETE /api/barang/:id)"]
        UC11["Tambah Akun Pegawai (POST /api/auth/pegawai)"]
        UC12["Buka & Tutup Lowongan (POST/PATCH /api/lowongan)"]
    end

    Pengunjung --> UC1
    Pengunjung --> UC2

    Warga --> UC2
    Warga --> UC3
    Warga --> UC4
    Warga --> UC5
    Warga --> UC6

    Pegawai --> UC2
    Pegawai --> UC3
    Pegawai --> UC7
    Pegawai --> UC8

    Pemilik --> UC2
    Pemilik --> UC3
    Pemilik --> UC7
    Pemilik --> UC8
    Pemilik --> UC9
    Pemilik --> UC10
    Pemilik --> UC11
    Pemilik --> UC12
```

---

## 3. Activity Diagram

### A. Alur Tambah / Ubah Barang Beserta Upload Foto Privat

```mermaid
flowchart TD
    A["Pemilik / Pegawai buka Form Barang di Flutter"] --> B["Pilih kategori, isi nama, harga, stok, satuan, pilih foto via ImagePicker"]
    B --> C["Kirim Multipart POST/PATCH /api/barang dengan Bearer JWT"]
    C --> D{"Middleware perluLogin & perluRole(pemilik, pegawai)"}
    D -- "Token tidak sah (401) / Role bukan toko (403)" --> E["Tolak permintaan & tampilkan pesan di Flutter"]
    D -- "Sah" --> F["Multer terima 1 file foto maks 5 MiB (memoryStorage)"]
    F --> G{"Validasi foto (MIME, penanda file, dekode ketat, <= 16 MP)"}
    G -- "Tidak valid (413/415)" --> E
    G -- "Valid" --> H["Validasi field barang (nama, kategori_id, harga, satuan, stok)"]
    H -- "Tidak valid (400)" --> E
    H -- "Valid" --> I["Simpan foto privat ke Cloudinary (authenticated) / folder lokal"]
    I --> J["INSERT / UPDATE tabel barang via 1 pool Drizzle db"]
    J -- "Error DB (FK / stok berubah)" --> K["Hapus foto yatim & kembalikan 400/409"]
    J -- "Berhasil" --> L["Hapus foto lama jika diganti, lalu ambil detail INNER JOIN kategori"]
    L --> M["Kembalikan JSON 201/200 ke Flutter & perbarui Katalog"]
```

### B. Alur Pemesanan Warga hingga Konfirmasi Pengurangan Stok

```mermaid
flowchart TD
    A["Warga pilih barang & jumlah di Katalog Flutter"] --> B["Tambahkan ke Keranjang & cek total rupiah"]
    B --> C["Tekan Kirim Pesanan (POST /api/pesanan + kunci_kirim 32 hex)"]
    C --> D["Mulai transaksi db.transaction()"]
    D --> E["Kunci baca barang & cek satuan, hitung subtotal akurat"]
    E --> F["Simpan ke tabel pesanan (Menunggu konfirmasi) & detail_pesanan"]
    F --> G["Pemilik / Pegawai buka Pesanan Masuk & tekan Konfirmasi"]
    G --> H["PATCH /api/pesanan/:id/konfirmasi dalam db.transaction()"]
    H --> I{"Cek status & kunci baris pesanan + barang (FOR UPDATE)"}
    I -- "Sudah dikonfirmasi" --> J["Kembalikan status Dikonfirmasi tanpa potong stok dua kali"]
    I -- "Stok kurang" --> K["Rollback transaksi seluruh item & kirim HTTP 409"]
    I -- "Stok cukup" --> L["Kurangi barang.stok & ubah status pesanan menjadi Dikonfirmasi"]
    L --> M["Commit transaksi; Warga melihat status Dikonfirmasi di Pesanan Saya"]
```

---

## 4. Class Diagram (Backend Express/Drizzle & Frontend Flutter)

```mermaid
classDiagram
    class RakRapiApi {
        +String alamat
        +String? token
        +Function? saatSesiHabis
        +cekKoneksi() Future~void~
        +masuk(email, sandi) Future~Json~
        +profil() Future~Json~
        +daftarWarga(nama, email, sandi) Future~void~
        +tambahPegawai(nama, email, sandi) Future~void~
        +daftarBarang() Future~List~
        +detail(id) Future~Json~
        +foto(id) Future~Uint8List~
        +simpanBarang(isian, id, gambar) Future~int~
        +kirimPesanan(kunci, item) Future~Json~
        +konfirmasiPesanan(id) Future~Json~
    }

    class RakRapiApp {
        +RakRapiApi api
        +SharedPreferencesAsync penyimpanan
        +Json? pengguna
        +pulihkanSesi()
        +masuk()
        +keluar()
    }

    class LayarKatalogDanForm {
        +DaftarBarang
        +DetailBarang
        +FormBarang
        +LayarKategori
        +Keranjang
        +LayarPesanan
        +LayarLowongan
    }

    class KonfigurasiDb {
        +opsiKoneksi(database) PoolOptions
        +pool MySql2Pool
        +db MySql2Database
    }

    class MiddlewareExpress {
        +aturCors(req, res, next)
        +perluLogin(req, res, next)
        +perluRole(roles)
        +terimaFoto(req, res, next)
        +tanganiError(err, req, res, next)
    }

    class LayananBackend {
        +akunService: daftarkanAkun, periksaLogin, ambilProfil, idPenggunaDariToken
        +kategoriService: ambilDaftarKategori, tambahKategori, ubahKategori, hapusKategori
        +barangService: ambilDaftarBarang, ambilDetailBarang, ambilFotoBarang, simpanBarang, hapusBarang
        +fotoService: siapkanFoto, tulisFoto, bacaFoto, hapusJikaLepas
        +lowonganService: daftarLowongan, bukaLowongan, tutupLowongan
        +pesananService: buatPesanan, daftarPesanan, ambilPesanan, konfirmasiPesanan
    }

    RakRapiApp --> RakRapiApi : memakai
    LayarKatalogDanForm --> RakRapiApi : memanggil REST API
    RakRapiApi ..> MiddlewareExpress : HTTPS/HTTP JSON & Multipart + Bearer JWT
    MiddlewareExpress --> LayananBackend : meneruskan request tervalidasi
    LayananBackend --> KonfigurasiDb : query via 1 pool Drizzle db
```

---

## 5. Tabel Hasil Pengujian Blackbox Aktual (22 November 2026)

Seluruh pengujian dijalankan terhadap backend hasil penyederhanaan (1 `.env`, 1 pool Drizzle `db`, 1 akun aplikasi `rakrapi_app`, JWT HS256 1 jam, Cloudinary privat) tanpa memodifikasi data asli:

| No | Modul | Skenario Pengujian | Hasil yang Diharapkan | Hasil Aktual | Status |
|---:|---|---|---|---|---|
| 1 | Build & Kualitas | `npm run build` (`tsc`) pada backend | Kompilasi TypeScript bersih tanpa error | Exit code 0, 0 error | **LULUS** |
| 2 | Kualitas Flutter | `flutter analyze --no-pub` & `flutter test --no-pub` | 0 issue analisis, seluruh tes widget & sesi lulus | 0 issue; **18/18 tes lulus** (`sesi_test`, `keranjang_test`, `form_barang_test`, `tampilan_test`) | **LULUS** |
| 3 | Koneksi Laragon | `GET /api/health` dengan 1 pool `db` (`rakrapi_app@localhost`, `DB_SSL=false`) | HTTP 200 `{"status":"ok","nama_database":"rakrapi"}` | HTTP 200 `{"status":"ok","nama_database":"rakrapi"}` | **LULUS** |
| 4 | Koneksi Aiven TLS | `GET /api/health` & `periksa-aiven.cjs` (`rakrapi_app@%`, `DB_SSL=true`, `DB_SSL_CA_BASE64`) | HTTP 200, `TLSv1.3`, `rejectUnauthorized: true`, hanya 6 tabel `rakrapi` terlihat | HTTP 200, `TLSv1.3`, `tls_terverifikasi: true`, 6 tabel `rakrapi`, `defaultdb` & `money_tracker` terisolasi | **LULUS** |
| 5 | Validasi TLS | Uji unit `test/koneksi.cjs` menolak Aiven dengan `DB_SSL=false`, CA kosong/invalid, port invalid | Melempar error sebelum membuka koneksi | 4/4 tes lulus (termasuk CORS `*` dan domain allowlist) | **LULUS** |
| 6 | Register Warga | `POST /api/auth/register` dengan `role: "pemilik"` di body & email duplikat | HTTP 201 dipaksa `role: "warga"`, duplikat HTTP 409, password di-hash `bcryptjs` | 201 `warga`, duplikat 409, `bcrypt.compare` cocok | **LULUS** |
| 7 | Login & JWT | `POST /api/auth/login` benar/salah pada Laragon & Aiven; uji 90 kasus HTTP di `test/jwt.cjs` | Login benar 200 (`HS256`, `exp=3600s`), sandi salah 401; token hilang/rusak/expired/`none`/secret salah/tanpa `exp` → 401 | **90/90 pemeriksaan HTTP JWT lulus**; login hash lama cost-10 tetap lulus | **LULUS** |
| 8 | Otorisasi 3 Role | Akses endpoint `/auth/pemilik`, `/auth/pegawai`, `/kategori`, `/barang`, `/lowongan`, `/pesanan` oleh 3 role + perubahan role langsung di MySQL | Pemilik 200/201, pegawai & warga 403 pada rute terlarang; perubahan role di MySQL langsung berlaku tanpa token baru | Seluruh matriks 200/201/403 lulus; role terbaru terbaca live dari MySQL | **LULUS** |
| 9 | CRUD Kategori | Pemilik tambah (201), duplikat (409), kosong (400), ubah (200), hapus kosong (204), hapus terpakai (409 `ON DELETE RESTRICT`) | Semua status tepat; kategori terpakai gagal dihapus | Seluruh skenario lulus; pesan penolakan 409 tampil tepat | **LULUS** |
| 10 | CRUD Barang & JOIN | Tambah barang berfoto (201), baca daftar/detail `INNER JOIN kategori` (200), ubah harga/stok tanpa ganti foto (200), ubah satuan/foto (200), hapus barang oleh pemilik (204) vs pegawai (403) | `nama_kategori` tampil dari `INNER JOIN`, foto lama utuh jika tidak diganti, foto terhapus saat barang dihapus | 5/5 rangkaian `test/katalog.cjs` lulus (termasuk pemulihan file yatim saat restart) | **LULUS** |
| 11 | Validasi & Foto Privat | Unggah PNG/JPEG valid, PNG korup, JPEG scan korup/kosong, MIME palsu, >5 MiB, >16 MP; baca foto ID 2 via Cloudinary privat pada Laragon & Aiven | Valid diterima byte identik; korup/palsu/>16 MP → 415; >5 MiB → 413; foto ID 2 privat 200 dengan SHA-256 identik | 4/4 `test/foto.cjs` lulus; foto ID 2 dari Cloudinary `2.200.991` byte SHA-256 identik (`D731582F...`) pada Laragon & Aiven | **LULUS** |
| 12 | Lowongan | Pemilik buka (201) & tutup (204), warga baca aktif saja (200), pegawai/warga kelola (403) | Lowongan tertutup hilang di daftar warga, tetap tercatat bagi pemilik | Lulus di `test/akun.cjs` | **LULUS** |
| 13 | Keranjang, Pesanan & Stok | Warga kirim pesanan (201, `kunci_kirim`), 2 petugas konfirmasi bersamaan (200, stok berkurang sekali), stok kurang (409 rollback utuh), lintas warga (404), harga lama tersimpan | Stok akhir akurat (`14→12` & `12.5→10`), tidak ada pengurangan ganda atau parsial, harga saat pesan tersimpan (`Rp19.000`, total `Rp73.000`) | Lulus penuh di `test/akun.cjs --uji-pesanan` | **LULUS** |
| 14 | Integritas Data Asli | Audit read-only Laragon, Aiven (`rakrapi`, `defaultdb`, `money_tracker`), stored procedure `tambah_pegawai`, 4 akun lama, foto lokal & backup | Data asli 100% utuh, proyek lain di Aiven tidak tersentuh | `users=4`, `kategori=1`, `barang=1` (ID 2 Rp19.000, 12 botol), `defaultdb` & `money_tracker` identik, `tambah_pegawai` utuh, SHA-256 foto lokal = backup = Cloudinary | **LULUS** |
| 15 | Konkurensi Foto & Transaksi | 10 baca foto paralel; edit harga + 6 baca foto paralel; ganti foto A→B + 8 baca foto paralel (tanpa `GET_LOCK`); 3 kirim pesanan identik (`kunci_kirim`); 3 konfirmasi pesanan serentak | Baca paralel 10/10 identik; edit harga tidak merusak foto; ganti foto berakhir konsisten 1 file foto B tanpa korup; pesanan tidak duplikat; stok terpotong tepat sekali (`10→7`) | 10/10 baca 200 identik; 6/6 baca saat edit harga 200 identik; ganti foto 200 (`8/8` fotoA, `0` race 404, `0` korup, akhir fotoB 1 file); `jumlahBarisPesanan=1`; stok akhir `7.000` | **LULUS** |
| 16 | Audit Layar, Tombol & Navigasi Flutter | Pemeriksaan seluruh 10 layar, seluruh tombol/navigasi, dan uji widget/sesi untuk 3 role (`main`, `katalog`, `form_barang`, `form_akun`, `kategori`, `keranjang`, `pesanan`, `lowongan`) | Tidak ada tombol mati/palsu; tab Bansos jujur menampilkan status disiapkan tanpa form palsu; seluruh alur 3 role bekerja | `flutter analyze` 0 issue; **18/18 `flutter test` lulus**; 0 tombol palsu/mati ditemukan | **LULUS** |
| 17 | Build Android Release APK | `flutter build apk --release` pada `frontend/` (tanpa `--no-pub` agar `GeneratedPluginRegistrant.java` bersih dari plugin test) | `app-release.apk` terbentuk utuh tanpa error kompilasi Gradle/Java | `app-release.apk` berhasil dibangun (**50,38 MB** / `52.826.453` byte; SHA-256 `42C7853212850B5C0378DCE672A608C188AEA5AE51318AA4FE974E2AA6F84929`; default `API_URL=http://127.0.0.1:3000/api`) | **LULUS** |
