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

## Autentikasi

Di `.env`, `DB_USER` dan `DB_PASSWORD` memakai akun health.
`AUTH_DB_USER` dan `AUTH_DB_PASSWORD` memakai akun MySQL `rakrapi_auth@localhost`.
Hak akun auth hanya SELECT pada lima kolom `users` dan INSERT pada
`nama`, `email`, `password_hash`. Isi `JWT_SECRET` dengan kunci acak privat
minimal 32 byte. Saat demo, kirim permintaan ke `http://127.0.0.1:3000`.

| Endpoint | Cara menggunakan |
|---|---|
| `POST /api/auth/register` | Kirim JSON berisi `nama`, `email`, `password`. Pendaftaran publik selalu menghasilkan pegawai. |
| `POST /api/auth/login` | Kirim `email` dan `password`. Respons sukses berisi profil dan JWT yang berlaku satu jam. |
| `GET /api/auth/me` | Kirim header `Authorization: Bearer <token>` untuk membaca profil sendiri. |
| `GET /api/auth/pemilik` | Gunakan header yang sama untuk memeriksa akses khusus pemilik. |

**Menyiapkan pemilik uji.** Daftarkan akun melalui endpoint register.
Catat ID dari respons 201. Admin lokal memeriksa ID dan email akun yang baru
dibuat, lalu mengubah role hanya untuk baris itu. Login sebagai akun tersebut
dan uji kembali endpoint pemilik. Aplikasi tidak mempunyai izin UPDATE.

**Hasil uji Laragon Fase 4B.** Register dengan tambahan `role: "pemilik"`
menghasilkan 201 dan role tersimpan `pegawai`. Email duplikat menghasilkan
409. Sandi salah menghasilkan 401; sandi benar menghasilkan 200 untuk kedua
role. Profil dengan token valid menghasilkan 200 untuk keduanya; tanpa token
atau dengan token tidak valid menghasilkan 401. Endpoint pemilik menghasilkan
403 untuk pegawai dan 200 untuk pemilik. Health menghasilkan 200 dengan
`nama_database` bernilai `rakrapi`. Sesudah uji, ada dua akun, nol kategori,
dan nol barang.

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
