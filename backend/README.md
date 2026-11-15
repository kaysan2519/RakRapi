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
