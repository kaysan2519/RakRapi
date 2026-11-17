# RakRapi

RakRapi adalah katalog toko untuk Android. Ketiga peran masuk ke katalog. Pemilik mengelola kategori, pegawai, dan lowongan. Pemilik serta pegawai dapat menambah dan mengubah barang. Warga membaca katalog, melihat lowongan aktif, dan membuka tab Bansos.

## Menjalankan demo lokal

1. Aktifkan MySQL 8.0.30 di Laragon. Pada laptop demo ini database `rakrapi` dan konfigurasi privat backend sudah tersedia.
2. Buka terminal PowerShell pertama untuk backend. Jika API sudah berjalan dan health mengembalikan 200, langsung gunakan terminal kedua.

```powershell
Set-Location C:\Users\Kaysan\UjiLevel\backend
npm.cmd run build
npm.cmd start
```

3. Buka terminal kedua untuk emulator Pixel 8. Jalankan perintah peluncuran emulator jika belum aktif, lalu tunggu sampai Android siap.

```powershell
Set-Location C:\Users\Kaysan\UjiLevel\frontend
flutter.bat emulators --launch Pixel_8
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 reverse tcp:3000 tcp:3000
flutter.bat run -d emulator-5554 --no-pub
```

## Alur presentasi

Untuk latihan yang mencakup tambah, ubah, dan hapus, gunakan database demo terpisah. Di terminal backend jalankan `node --env-file=.env test/akun.cjs --demo`. Terminal menunjukkan lokasi file lokal berisi tiga akun sementara dan dua perintah untuk membuka Flutter pada port demo. Katalog demo dimulai kosong. Tekan Enter setelah latihan untuk menutup API uji dan membersihkan akun, foto, dan database sementara.

- **Pemilik** membuka **Menu pemilik → Kelola kategori** untuk membaca detail, mengubah nama, atau menghapus dengan konfirmasi. Kategori yang masih dipakai mendapat pesan penolakan. Dari **Tambah barang**, isi kategori, harga dan stok, pilih foto, lalu simpan. Gunakan data toko yang memang ingin disimpan saat memakai katalog utama.
- **Pegawai** membuka **Minyak goreng 1 L** untuk melihat harga, stok, kategori dan foto. Untuk menjelaskan asal nama kategori, ikuti [route](backend/src/routes/barang.routes.ts), [controller](backend/src/controllers/barang.controller.ts), lalu [INNER JOIN pada service](backend/src/services/barang.service.ts).
- **Warga** masuk dari layar yang sama dan melihat beranda bansos. Tombol **Keluar** memungkinkan pengguna berpindah akun.

Petunjuk API dan SQL ada di [panduan backend](backend/README.md). Pengujian Android memakai [panduan Flutter](frontend/README.md). Rancangan, diagram, dan hasil uji tersedia di [SRS RakRapi](docs/SRS-RakRapi.docx).
