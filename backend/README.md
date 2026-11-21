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

## Mode Aiven dan DBeaver

Semua konfigurasi aktif sekarang berada di **`backend/.env`**. Template tunggal
adalah `.env.example`; jangan menimpa `.env` milikmu dengan template kosong.
`DB_MODE=laragon` menggunakan host lokal dan port 3306. Untuk Aiven, ubah
`DB_MODE=aiven`, host dan port layanan, lalu isi `DB_SSL_CA=private/aiven/ca.pem`.
API tetap memakai `PORT=3000`, sehingga alamat Flutter tidak perlu berubah.
CA adalah berkas sertifikat, bukan file env tambahan.

Akun health, auth, pegawai, dan katalog tetap berbeda karena hak aksesnya berbeda.
Mengumpulkan variabel di satu file tidak menyatukan akun atau menambah izin.
`ADMIN_DB_USER` dan `ADMIN_DB_PASSWORD` hanya dibaca pemeriksa Aiven dengan
opsi `--admin`; server API tidak memakai kredensial admin.

**Pindah dari konfigurasi lama (sekali, di laptop):**
1. Simpan salinan privat konfigurasi lama sebelum merapikan. Jangan commit sandi.
2. Pilih satu tujuan aktif. Untuk Laragon, pertahankan nilai `.env` yang sudah bekerja.
   Untuk Aiven, pindahkan nilai koneksi dan keempat akun aplikasi dari `.env.aiven`
   ke `.env`. Jangan membawa akun Laragon ke host Aiven.
3. Dari `private/aiven/admin.env`, pindahkan nilai `DB_USER`/`DB_PASSWORD` ke
   `ADMIN_DB_USER`/`ADMIN_DB_PASSWORD`. Jangan menimpa akun health dengan admin.
4. Bila memakai tes demo, pindahkan `DEMO_PEMILIK_PASSWORD` dan
   `DEMO_PEGAWAI_PASSWORD` dari `.env.demo` ke `.env`.
5. Setelah koneksi dan fitur teruji, file env lama tidak lagi diperlukan oleh
   perintah dalam repo. Jangan hapus sebelum nilai privatnya berhasil dipindahkan.

Pada laptop ini, konfigurasi Laragon dan sandi demo sudah disatukan di `.env`
pada 18 November 2026. Nilai koneksi, sandi, dan JWT yang sebelumnya bekerja
dipertahankan; salinan privat konfigurasi lama masih disimpan di `private/`.
Mode aktif tetap `laragon`. Kredensial Aiven belum lengkap, sehingga penyatuan
file ini **belum berarti** Aiven sudah tersambung.

[koneksi.ts](src/config/koneksi.ts) menyusun opsi untuk semua pool MySQL.
Mode Aiven wajib memakai host layanan, kredensial, dan CA. `rejectUnauthorized`
dan `verifyIdentity` selalu aktif: sertifikat serta nama host harus cocok.
File foto mode Aiven memakai `private/uploads-aiven/db-rakrapi`; foto Laragon
tetap di `private/uploads/db-rakrapi`. Penyimpanan foto ini masih di laptop,
bukan di Aiven. Jangan arahkan `UPLOAD_DIR` kedua lingkungan ke folder yang sama.

**DBeaver** adalah alat untuk melihat tabel dan menjalankan SQL. Backend tetap
menggunakan mysql2 + Drizzle, tanpa bergantung pada DBeaver. Buat koneksi MySQL
ke host/port dari halaman Overview Aiven, gunakan database awal `defaultdb`,
dan isi sandi di laptop. Pada pengaturan SSL, pilih CA layanan dan verifikasi
sertifikat server. Untuk driver MySQL Connector/J, gunakan
`sslMode=VERIFY_IDENTITY`; jangan aktifkan kepercayaan pada semua sertifikat.
Pilih Test Connection, lalu lihat database dan tabel sebelum menjalankan SQL.

Pemeriksaan baca saja yang memakai koneksi dan CA yang sama:

```powershell
npm.cmd run build
npm.cmd run cek:aiven
# Opsional, untuk melihat tabel dengan akun administrator:
npm.cmd run cek:aiven -- --admin
```

Pemeriksaan ini hanya membaca data. Script melaporkan host, port, hasil verifikasi TLS,
sidik sertifikat, server MySQL, daftar tabel, dan hasil `SELECT DATABASE()`
melalui Drizzle bila `rakrapi` sudah ada. Script tidak menampilkan sandi
dan tidak menerapkan migration. Jika ada tabel proyek lain, berhenti sebelum
perubahan. Jika `rakrapi` sudah berisi tabel, bandingkan skemanya terlebih dahulu.

Untuk database tujuan yang sudah dipastikan kosong, urutan SQL adalah
`01_skema.sql`, `03_role_warga.sql`, `04_prosedur_pegawai.sql`,
`05_lowongan.sql`, lalu `06_pesanan.sql`, dengan database aktif `rakrapi`.
Jangan jalankan `02_demo.sql`, seed, atau runner tes pada Aiven.
Gunakan akun aplikasi terpisah dengan hak setara akun lokal: health membaca
`kategori.id`, auth membaca profil dan memasukkan nama/email/hash tanpa hak
menulis role, pegawai hanya EXECUTE prosedur `tambah_pegawai`, dan katalog
memakai hak tabel yang didokumentasikan di bawah. Konfirmasikan penyiapan
akun Aiven sebelum memberinya izin; jangan gunakan administrator sebagai akun API.

Setelah skema, akun aplikasi, dan `.env` tersedia, jalankan:

```powershell
npm.cmd start
```

Di terminal lain:

```powershell
curl.exe -i http://127.0.0.1:3000/api/health
```

HTTP 200 saja belum membuktikan Aiven. Cocokkan dengan keluaran pemeriksaan
host dan TLS di atas. Per 18 November 2026, host/CA layanan sudah diperiksa,
namun kredensial privat belum diisi; pemeriksaan tabel, migration dan HTTP 200
dari Aiven **belum teruji**. Layanan yang ditemukan berpaket Developer-1 dengan
kredit trial, bukan paket Free. Tidak ada perubahan paket atau pembelian.
Deployment website Vercel/Netlify dan hosting API tetap langkah tersendiri.

## Cara membaca backend RakRapi

Ikuti permintaan pegawai yang sudah masuk dan membuka `GET /api/barang/2`. Tiga file pertama menunjukkan alur utamanya.

1. [barang.routes.ts](src/routes/barang.routes.ts) memasangkan `GET /:id` dengan `detailBarang`. Awalan `/api/barang` terdaftar di [app.ts](src/app.ts). Sebelum controller dipanggil, `perluLogin` memeriksa JWT dan memuat profil. Lalu `perluRole("pemilik", "pegawai", "warga")` memeriksa hak baca. Kedua pemeriksaan ada di [akses.middleware.ts](src/middleware/akses.middleware.ts).
2. [barang.controller.ts](src/controllers/barang.controller.ts) berisi `detailBarang`. Fungsi ini membaca `"2"` dari URL. `bilanganBulat` memvalidasinya menjadi angka `2`. Controller meneruskan angka itu ke `ambilDetailBarang`, lalu mengirim hasilnya sebagai JSON `{ data }`.
3. [barang.service.ts](src/services/barang.service.ts) berisi `ambilDetailBarang`. Fungsi ini memakai query `barangDenganKategori` dan memilih baris dengan `barang.id = 2`. `innerJoin` mencocokkan `barang.kategori_id` dengan `kategori.id`, sehingga `kategori.nama` bisa dikirim sebagai `nama_kategori`. Jika baris kosong, hasilnya 404. Untuk barang yang ditemukan, `sertakanUrlFoto` menambahkan `/api/barang/2/foto`.

**Foto.** Flutter meminta `foto_url` dengan token yang sama. Dari route `GET /:id/foto`, ikuti `kirimFotoBarang` di controller barang, lalu `ambilFotoBarang` di service barang. Service membaca `foto_key`, kemudian `bacaFoto` di [foto.service.ts](src/services/foto.service.ts) membuka file privat. Controller mengirim isi file dengan tipe gambarnya.

**Login.** Mulai dari [akun.routes.ts](src/routes/akun.routes.ts), buka `login` di [akun.controller.ts](src/controllers/akun.controller.ts), lalu `periksaLogin` di [akun.service.ts](src/services/akun.service.ts) untuk melihat pemeriksaan sandi dan pembuatan JWT.

**Kategori.** Mulai dari [kategori.routes.ts](src/routes/kategori.routes.ts) untuk melihat akses pemilik. Ikuti fungsi pada baris route ke [kategori.controller.ts](src/controllers/kategori.controller.ts), lalu lihat query di [kategori.service.ts](src/services/kategori.service.ts). Definisi tabel barang, kategori, dan pengguna ada di [schema.ts](src/config/schema.ts).

## Autentikasi

Di `.env`, `DB_USER` dan `DB_PASSWORD` memakai akun health.
`AUTH_DB_USER` dan `AUTH_DB_PASSWORD` memakai akun MySQL `rakrapi_auth@localhost`.
Hak akun auth hanya SELECT pada lima kolom `users` dan INSERT pada
`nama`, `email`, `password_hash`. Isi `JWT_SECRET` dengan kunci acak privat
minimal 32 byte. Saat demo, kirim permintaan ke `http://127.0.0.1:3000`.

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
pengguna melalui `authDb` sesuai konfigurasi aktif, lalu memeriksa sandi dengan
`bcrypt.compare`. `buatToken` menandatangani JWT memakai `JWT_SECRET` dari `.env`,
algoritma **HS256**, issuer `rakrapi`, dan masa berlaku **1 jam (3.600 detik)**.
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

**Migration tiga peran.** Setelah skema awal, jalankan `database/03_role_warga.sql` dan `database/04_prosedur_pegawai.sql` pada database yang dipilih. Migration mengubah default dan pemeriksaan role untuk pendaftaran berikutnya. Untuk endpoint pegawai, isi `PEGAWAI_DB_USER` dan `PEGAWAI_DB_PASSWORD` dari akun localhost terpisah. Satu-satunya grant aplikasi untuk akun itu adalah `GRANT EXECUTE ON PROCEDURE rakrapi.tambah_pegawai TO 'rakrapi_pegawai'@'localhost'`. Prosedur menerima nama, email, dan hash lalu mengisi role pegawai sendiri.

Dari folder backend, jalankan `npm.cmd run build`, lalu `node --env-file=.env test/akun.cjs` untuk uji HTTP terisolasi. Tambahkan `emulator-5554` di akhir perintah untuk menguji formulir serta pemulihan sesi ketiga peran melalui Flutter. Runner menggunakan profil admin lokal MySQL `rakrapi` untuk membuat dan membersihkan database uji.

Akun demo lokal: `pegawai.uji@rakrapi.test` dan `pemilik.uji@rakrapi.test`.
Sandi demo opsional disimpan pada bagian `DEMO_*` di `.env`. Git mengabaikan `.env`.

## Katalog dan foto lokal

Mulai MySQL Laragon di port 3306. Gunakan `.env` yang sudah disiapkan pada
komputer ini. Akun `rakrapi_katalog@localhost` melalui `CATALOG_DB_USER` dan
`CATALOG_DB_PASSWORD` mempunyai SELECT, INSERT, UPDATE, dan DELETE
pada `rakrapi.kategori` dan `rakrapi.barang`. Pada database baru, jalankan `database/05_lowongan.sql`, lalu beri akun katalog hak berikut.

```sql
GRANT SELECT, INSERT (judul), UPDATE (aktif) ON rakrapi.lowongan TO 'rakrapi_katalog'@'localhost';
```

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

Untuk instalasi baru, terapkan `database/06_pesanan.sql` setelah migration 05. Akun katalog memakai hak berikut pada kedua tabel baru.

```sql
GRANT SELECT, INSERT, UPDATE (status) ON rakrapi.pesanan TO 'rakrapi_katalog'@'localhost';
GRANT SELECT, INSERT ON rakrapi.detail_pesanan TO 'rakrapi_katalog'@'localhost';
```

Harga satuan, nama barang, dan satuan disalin ke rincian ketika pesanan dibuat. Subtotal dibulatkan ke rupiah terdekat per baris, lalu dijumlahkan. Saat konfirmasi, service mengunci baris pesanan dan barang dalam urutan ID. Kekurangan stok membatalkan transaksi dan API mengirim 409 beserta nama barang. Jalankan `node --env-file=.env test/akun.cjs --uji-pesanan` dari folder ini untuk menguji aturan itu di MySQL terpisah.

Untuk menambah barang, kirim `multipart/form-data` dengan `nama`,
`kategori_id`, `harga_rupiah`, `stok`, `satuan`, dan satu file pada kolom
`foto`. Harga berupa rupiah bulat mulai dari nol. Stok botol harus bulat;
stok kg boleh memiliki maksimal tiga desimal. Misalnya, stok `12` bersatuan
`botol` atau `2,125` bersatuan `kg`. Untuk mengubah harga atau stok saja,
PATCH menerima JSON, misalnya `{"harga_rupiah":20000,"stok":10}`. Untuk
mengganti foto, gunakan PATCH multipart dengan file `foto` baru.

Multer membatasi unggahan ke satu JPEG/PNG, maksimal 5 MiB. Selain MIME dan
tanda format file, decoder gambar bawaan Windows (Windows PowerShell dan
System.Drawing) memeriksa isi gambar serta batas 16 megapiksel. Backend
menyimpan byte asli di `private/uploads/db-rakrapi/`; hanya `foto_key`
tersimpan di tabel. Folder ini diabaikan Git dan hanya disajikan lewat
endpoint yang memeriksa login.

File baru ditulis sebelum referensinya disimpan di MySQL. Jika SQL gagal,
backend memeriksa referensi sebelum membersihkan file baru. Untuk penggantian
dan penghapusan, file lama dibersihkan setelah perubahan baris berhasil.
Saat restart, backend memeriksa kembali file miliknya yang tidak dirujuk.

### Mengulangi uji HTTP

Dari folder `backend` dengan MySQL Laragon aktif:

```powershell
npm.cmd run build
node --env-file=.env --test test/katalog.cjs
```

Uji memakai profil admin CLI MySQL `rakrapi` hanya untuk penyiapan dan
pembersihan lingkungan uji. Nama database dan akun uji dibuat unik, foto
masuk ke direktori sementara, sedangkan login memakai akun demo lokal.
Uji memeriksa CRUD, hak akses, penolakan hapus kategori terpakai, data dan
file salah, foto lama saat ubah harga/stok, serta isi foto setelah restart.
