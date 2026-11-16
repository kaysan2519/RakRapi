# Backend RakRapi

Dari folder `backend`, gunakan Node.js 22.9 atau lebih baru. Salin
`.env.example` ke `.env` dan isi akun MySQL Laragon yang dapat mengakses
database `rakrapi`.

```powershell
npm.cmd ci
npm.cmd run build
npm.cmd start
```

Di terminal kedua, jalankan `curl.exe -i http://127.0.0.1:3000/api/health`.
Status 200 berarti query melalui Drizzle mengembalikan nama database
`rakrapi`. Jika koneksi gagal atau nama database berbeda, statusnya 503.

## Cara membaca backend RakRapi

Ikuti permintaan pegawai yang sudah masuk dan membuka `GET /api/barang/2`. Tiga file pertama menunjukkan alur utamanya.

1. [barang.routes.ts](src/routes/barang.routes.ts) memasangkan `GET /:id` dengan `detailBarang`. Awalan `/api/barang` terdaftar di [app.ts](src/app.ts). Sebelum controller dipanggil, `perluLogin` memeriksa JWT dan memuat profil. Lalu `perluRole("pemilik", "pegawai")` memeriksa hak baca. Kedua pemeriksaan ada di [akses.middleware.ts](src/middleware/akses.middleware.ts).
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
Sandi demo ada di `.env.demo` pada komputer lokal. Git mengabaikan file itu
dan `.env`.

## Katalog dan foto lokal

Mulai MySQL Laragon di port 3306. Gunakan `.env` yang sudah disiapkan pada
komputer ini. Akun `rakrapi_katalog@localhost` melalui `CATALOG_DB_USER` dan
`CATALOG_DB_PASSWORD` hanya mempunyai SELECT, INSERT, UPDATE, dan DELETE
pada `rakrapi.kategori` dan `rakrapi.barang`.

| Endpoint (awalan `/api`) | Akses | Hasil |
|---|---|---|
| GET /kategori, GET /kategori/:id | Pemilik | Daftar/detail kategori |
| POST /kategori, PATCH /kategori/:id, DELETE /kategori/:id | Pemilik | Tambah, ubah nama, hapus kategori kosong |
| GET /barang, GET /barang/:id | Pemilik, pegawai | Data barang, nama kategori hasil INNER JOIN, dan `foto_url` |
| GET /barang/:id/foto | Pemilik, pegawai | Byte foto asli; kirim Bearer token juga ke URL ini |
| POST /barang, PATCH /barang/:id, DELETE /barang/:id | Pemilik | Tambah, ubah, hapus barang beserta fotonya |

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
