# Backend RakRapi

Dari folder `backend`, gunakan Node.js 22.9 atau lebih baru. Salin
`.env.example` ke `.env` dan isi akun MySQL Laragon yang dapat mengakses
database `rakrapi`.

```powershell
npm.cmd ci
npm.cmd run dev
# dev melakukan build lalu start; setelah mengedit backend, hentikan dan jalankan lagi.
```

Di terminal kedua, jalankan `curl.exe -i http://127.0.0.1:3000/api/health`.
Status 200 berarti query melalui Drizzle mengembalikan nama database
`rakrapi`. Jika koneksi gagal atau nama database berbeda, statusnya 503.

## Konfigurasi Sederhana (Satu `.env` dan Satu Pool Drizzle)

Seluruh konfigurasi aktif berada di **`backend/.env`** (template tanpa rahasia di `.env.example`; jangan unggah `.env` ke Git). Backend memakai **satu connection pool MySQL dan satu instance Drizzle ORM (`db`)** di [db.ts](src/config/db.ts) dan [koneksi.ts](src/config/koneksi.ts). Otorisasi peran `pemilik`, `pegawai`, dan `warga` dijaga oleh JWT HS256 (1 jam) dan middleware [akses.middleware.ts](src/middleware/akses.middleware.ts) yang selalu memeriksa role terbaru dari MySQL.

- **Mode Laragon lokal:** `DB_HOST=localhost`, `DB_PORT=3306`, `DB_USER=rakrapi_app` (atau `root`), `DB_NAME=rakrapi`, `DB_SSL=false`, `DB_SSL_CA_BASE64=`.
- **Mode Aiven:** isi `DB_HOST` dan `DB_PORT` Aiven, akun aplikasi non-admin `DB_USER=rakrapi_app` (`REQUIRE SSL`, izin khusus `rakrapi.*`, **bukan `avnadmin`**), `DB_SSL=true`, dan `DB_SSL_CA_BASE64` (hasil base64 dari `ca.pem`). [koneksi.ts](src/config/koneksi.ts) selalu mengaktifkan `rejectUnauthorized: true` dan `verifyIdentity: true`.
- **Cloudinary privat:** isi `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, dan `CLOUDINARY_API_SECRET` di `.env` agar foto disimpan sebagai aset privat (`authenticated`). Saat runner tes lokal mengatur `UPLOAD_DIR`, penyimpanan otomatis memakai folder sementara lokal.
- **CORS:** diatur lewat `CORS_ORIGIN` (`*` saat development, atau daftar domain web saat production).
- **Verifikasi Aiven (baca saja):**

```powershell
npm.cmd run build
npm.cmd run cek:aiven
```

Pengujian otomatis lokal (menggunakan database uji terisolasi tanpa menyentuh data asli `rakrapi`):

```powershell
npm.cmd run build
node --test test/koneksi.cjs
node --test test/foto.cjs
node --env-file=.env test/akun.cjs --uji-jwt
node --env-file=.env test/akun.cjs --uji-pesanan
node --env-file=.env --test test/katalog.cjs
```

## Cara membaca backend RakRapi

Ikuti permintaan pegawai yang sudah masuk dan membuka `GET /api/barang/2`. Tiga file pertama menunjukkan alur utamanya.

1. [barang.routes.ts](src/routes/barang.routes.ts) memasangkan `GET /:id` dengan `detailBarang`. Awalan `/api/barang` terdaftar di [app.ts](src/app.ts). Sebelum controller dipanggil, `perluLogin` memeriksa JWT dan memuat profil. Lalu `perluRole("pemilik", "pegawai", "warga")` memeriksa hak baca. Kedua pemeriksaan ada di [akses.middleware.ts](src/middleware/akses.middleware.ts).
2. [barang.controller.ts](src/controllers/barang.controller.ts) berisi `detailBarang`. Fungsi ini membaca `"2"` dari URL. `bilanganBulat` memvalidasinya menjadi angka `2`. Controller meneruskan angka itu ke `ambilDetailBarang`, lalu mengirim hasilnya sebagai JSON `{ data }`.
3. [barang.service.ts](src/services/barang.service.ts) berisi `ambilDetailBarang`. Fungsi ini memakai query `barangDenganKategori` dan memilih baris dengan `barang.id = 2`. `innerJoin` mencocokkan `barang.kategori_id` dengan `kategori.id`, sehingga `kategori.nama` bisa dikirim sebagai `nama_kategori`. Jika baris kosong, hasilnya 404. Untuk barang yang ditemukan, `sertakanUrlFoto` menambahkan `/api/barang/2/foto`.

**Foto.** Flutter meminta `foto_url` dengan token yang sama. Dari route `GET /:id/foto`, ikuti `kirimFotoBarang` di controller barang, lalu `ambilFotoBarang` di service barang. Service membaca `foto_key`, kemudian `bacaFoto` di [foto.service.ts](src/services/foto.service.ts) membuka file privat. Controller mengirim isi file dengan tipe gambarnya.

**Login.** Mulai dari [akun.routes.ts](src/routes/akun.routes.ts), buka `login` di [akun.controller.ts](src/controllers/akun.controller.ts), lalu `periksaLogin` di [akun.service.ts](src/services/akun.service.ts) untuk melihat pemeriksaan sandi dan pembuatan JWT.

**Kategori.** Mulai dari [kategori.routes.ts](src/routes/kategori.routes.ts) untuk melihat akses pemilik. Ikuti fungsi pada baris route ke [kategori.controller.ts](src/controllers/kategori.controller.ts), lalu lihat query di [kategori.service.ts](src/services/kategori.service.ts). Definisi tabel barang, kategori, dan pengguna ada di [schema.ts](src/config/schema.ts).

## Autentikasi

Di `.env`, seluruh modul backend memakai satu akun aplikasi (`DB_USER` & `DB_PASSWORD`) melalui satu pool Drizzle `db`. Isi `JWT_SECRET` dengan kunci acak privat minimal 32 byte, `JWT_EXPIRES_IN=1h`, dan `BCRYPT_SALT_ROUNDS=12`. Saat demo lokal, kirim permintaan ke `http://127.0.0.1:3000`.

| Endpoint | Cara menggunakan |
|---|---|
| `POST /api/auth/register` | Publik. Kirim `nama`, `email`, dan `password`. Server selalu membuat warga. |
| `POST /api/auth/pegawai` | Khusus pemilik dengan Bearer token. Kirim isian yang sama untuk membuat pegawai. |
| `POST /api/auth/login` | Kirim `email` dan `password`. Respons sukses berisi profil dan JWT yang berlaku satu jam. |
| `GET /api/auth/me` | Kirim header `Authorization: Bearer <token>` untuk membaca profil sendiri. |
| `GET /api/auth/pemilik` | Gunakan header yang sama untuk memeriksa akses khusus pemilik. |

### JWT dan sesi aplikasi

Login di [akun.controller.ts](src/controllers/akun.controller.ts) memanggil
`periksaLogin` di [akun.service.ts](src/services/akun.service.ts). Service membaca
pengguna melalui satu pool Drizzle `db`, lalu memeriksa sandi dengan
`bcrypt.compare`. `buatToken` menandatangani JWT memakai `JWT_SECRET` dari `.env`,
algoritma **HS256**, issuer `rakrapi`, dan masa berlaku **`JWT_EXPIRES_IN` (`1h` / 3.600 detik)**.
Payload hanya memuat `sub` (ID), `iss`, `iat`, dan `exp`; sandi/hash tidak dikirim.

`idPenggunaDariToken` memanggil `jwt.verify` dengan daftar algoritma HS256,
memeriksa issuer, signature, kedaluwarsa, serta mewajibkan `exp` dan ID yang valid.
[akses.middleware.ts](src/middleware/akses.middleware.ts) mengambil profil/role
terbaru dari MySQL pada setiap permintaan. Token hilang/tidak sah atau pengguna
tidak ditemukan menghasilkan 401; pengguna tanpa hak menghasilkan 403.
Register publik tetap warga dan Tambah pegawai tetap hanya untuk pemilik.

Flutter [api.dart](../frontend/lib/api.dart) mengirim Bearer melalui `_kirim`,
termasuk foto dan multipart. [main.dart](../frontend/lib/main.dart) menyimpan
token dengan `SharedPreferencesAsync`, memulihkannya melalui `/auth/me`, dan
menghapusnya saat keluar. Respons 401 privat mengembalikan layar Masuk dengan
pesan singkat; 403, jaringan gagal, timeout, dan 503 tidak menghapus sesi.

**Batas logout:** keluar menghapus token di perangkat. Salinan JWT yang sudah
dimiliki pihak lain masih berlaku sampai `exp`, selama akun dan izin masih valid.
Tidak ada pencabutan token di server atau refresh token; pengguna masuk kembali
setelah token habis. Perubahan role di database langsung berlaku pada token lama.

**Audit 19 November 2026:** 90 pemeriksaan JWT HTTP dan 5 tes katalog lulus pada
database uji terpisah; 18 tes Flutter (termasuk 9 tes sesi) lulus dan analyze bersih.
Kasus mencakup login benar/salah, token hilang/rusak/kedaluwarsa/tanpa `exp`,
signature salah, algoritma lain/`none`, issuer salah, tiga peran, role palsu dalam
token, serta perubahan role di MySQL tanpa menerbitkan token baru. Tes Flutter
memakai HTTP/persistensi di memori untuk memeriksa Bearer, pemulihan, 401 pada
profil/foto, logout, dan gangguan jaringan; tidak menulis katalog utama.
Sesudah backend direstart, health/login/profil/detail/foto ID 2 di Laragon utama
memberi 200; harga Rp19.000, stok 12 botol, `foto_key` dan byte foto tetap sama.

Ulangi tes dari folder backend dengan MySQL Laragon aktif:

```powershell
npm.cmd run build
node --env-file=.env test/akun.cjs --uji-jwt
node --env-file=.env --test test/katalog.cjs
# Dari folder frontend: flutter test --no-pub test/sesi_test.dart
```

**Pemilik uji.** Gunakan akun pemilik yang sudah tersedia di Laragon untuk
menguji menu Tambah pegawai. Login pemilik memakai endpoint yang sama dengan
login pegawai dan warga.

**Arsip uji Fase 4B sebelum migration warga.** Register dengan tambahan `role: "pemilik"`
menghasilkan 201 dan role tersimpan `pegawai`. Email duplikat menghasilkan
409. Sandi salah menghasilkan 401; sandi benar menghasilkan 200 untuk kedua
role. Profil dengan token valid menghasilkan 200 untuk keduanya; tanpa token
atau dengan token tidak valid menghasilkan 401. Endpoint pemilik menghasilkan
403 untuk pegawai dan 200 untuk pemilik. Health menghasilkan 200 dengan
`nama_database` bernilai `rakrapi`. Sesudah uji, ada dua akun, nol kategori,
dan nol barang.

**Migration tiga peran & stored procedure.** Setelah skema awal, jalankan `database/03_role_warga.sql` dan `database/04_prosedur_pegawai.sql` pada database yang dipilih. Stored procedure `tambah_pegawai` tetap dipertahankan di database Laragon dan Aiven. Pada kode aplikasi sederhana saat ini, backend menggunakan satu pool Drizzle (`db`) dengan satu akun aplikasi (`rakrapi_app`), sedangkan pembatasan pembuatan pegawai dan register warga dijaga oleh middleware JWT `perluLogin` dan `perluRole("pemilik")`.

Dari folder backend, jalankan `npm.cmd run build`, lalu `node --env-file=.env test/akun.cjs --uji-jwt` dan `node --env-file=.env test/akun.cjs --uji-pesanan` untuk uji HTTP terisolasi. Runner menggunakan profil admin lokal MySQL `rakrapi` hanya untuk membuat dan membersihkan database uji sementara tanpa menyentuh data asli.

Akun demo lokal yang sudah ada di database utama: `pegawai.uji@rakrapi.test` dan `pemilik.uji@rakrapi.test` (sandi tidak disimpan di Git).

## Katalog dan foto privat

Mulai MySQL Laragon di port 3306 dan gunakan `backend/.env` aktif dengan satu akun aplikasi (`rakrapi_app` atau `root` Laragon) yang memiliki izin `SELECT, INSERT, UPDATE, DELETE` pada `rakrapi.*`. Pada database baru, jalankan `database/05_lowongan.sql` dan `database/06_pesanan.sql`.

| Endpoint (awalan `/api`) | Akses | Hasil |
|---|---|---|
| GET /kategori | Pemilik, pegawai | ID dan nama kategori |
| GET /kategori/:id | Pemilik | Detail kategori |
| POST /kategori, PATCH /kategori/:id, DELETE /kategori/:id | Pemilik | Tambah, ubah nama, hapus kategori kosong |
| GET /barang, GET /barang/:id | Ketiga peran | Data barang, nama kategori hasil INNER JOIN, dan `foto_url` |
| GET /barang/:id/foto | Ketiga peran | Byte foto asli dengan Bearer token |
| POST /barang, PATCH /barang/:id | Pemilik, pegawai | Tambah atau ubah barang dan foto |
| DELETE /barang/:id | Pemilik | Hapus barang beserta fotonya |
| GET /lowongan | Pemilik, warga | Semua untuk pemilik, hanya yang aktif untuk warga |
| POST /lowongan, PATCH /lowongan/:id/tutup | Pemilik | Buka lowongan dengan field `judul` atau tutup lowongan |
| POST /pesanan | Warga | Kirim `kunci_kirim` (32 digit heksadesimal) dan `item` berisi `barang_id`, `jumlah`, dan `satuan` |
| GET /pesanan, GET /pesanan/:id | Ketiga peran | Warga hanya melihat pesanan sendiri. Toko dapat melihat semua pesanan |
| PATCH /pesanan/:id/konfirmasi | Pemilik, pegawai | Konfirmasi dan kurangi stok di satu transaksi. Konfirmasi ulang mengembalikan status terakhir |

Harga satuan, nama barang, dan satuan disalin ke rincian ketika pesanan dibuat. Subtotal dibulatkan ke rupiah terdekat per baris, lalu dijumlahkan. Saat konfirmasi, service mengunci baris pesanan dan barang dalam urutan ID. Kekurangan stok membatalkan transaksi dan API mengirim 409 beserta nama barang. Jalankan `node --env-file=.env test/akun.cjs --uji-pesanan` dari folder ini untuk menguji aturan itu di MySQL terpisah.

Untuk menambah barang, kirim `multipart/form-data` dengan `nama`,
`kategori_id`, `harga_rupiah`, `stok`, `satuan`, dan satu file pada kolom
`foto`. Harga berupa rupiah bulat mulai dari nol. Stok botol harus bulat;
stok kg boleh memiliki maksimal tiga desimal. Misalnya, stok `12` bersatuan
`botol` atau `2,125` bersatuan `kg`. Untuk mengubah harga atau stok saja,
PATCH menerima JSON, misalnya `{"harga_rupiah":20000,"stok":10}`. Untuk
mengganti foto, gunakan PATCH multipart dengan file `foto` baru.

Multer membatasi unggahan ke satu JPG/PNG/WebP, maksimal 5 MiB. Validasi gambar di
[foto.validation.ts](src/validations/foto.validation.ts) memeriksa ukuran, kecocokan MIME dengan
penanda biner (*magic bytes*), struktur chunk/marker (termasuk CRC32 PNG bawaan Node.js), dan
batas 16 megapiksel tanpa mengubah byte foto asli maupun memakai library pengolah gambar eksternal. Jika
`CLOUDINARY_*` terisi di `.env`, foto disimpan privat (`type: "authenticated"`) di
Cloudinary dan disajikan melalui `GET /api/barang/:id/foto` yang mewajibkan JWT.
Saat pengujian lokal dengan `UPLOAD_DIR`, foto disimpan di folder sementara lokal.

File baru ditulis sebelum referensinya disimpan di MySQL. Jika SQL gagal,
backend memeriksa referensi sebelum membersihkan file baru. Untuk penggantian
dan penghapusan, file lama dibersihkan setelah perubahan baris berhasil.
Saat restart dalam mode lokal, `pulihkanFoto()` membersihkan file yatim yang tidak dirujuk.

### Mengulangi uji HTTP

Dari folder `backend` dengan MySQL Laragon aktif:

```powershell
npm.cmd run build
node --test test/koneksi.cjs
node --test test/foto.cjs
node --env-file=.env test/akun.cjs --uji-jwt
node --env-file=.env test/akun.cjs --uji-pesanan
node --env-file=.env --test test/katalog.cjs
```

Seluruh runner memakai database dan akun sementara yang dibuat lalu dihapus otomatis
setelah selesai, sehingga data asli `rakrapi` tidak pernah berubah.
