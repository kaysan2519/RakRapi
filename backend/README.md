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
