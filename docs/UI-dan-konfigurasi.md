# Perubahan UI dan konfigurasi RakRapi

Dasar: commit `fe89281` pada `feat/penuntasan-katalog`.
Pekerjaan dilakukan di branch terpisah `feat/ui-env-sederhana` agar checkout dan
perubahan manual di laptop tidak ditimpa.

## Hasil

- Satu template `.env.example`, satu konfigurasi aktif `backend/.env` untuk API,
  pemeriksaan Aiven, dan sandi demo opsional. Panduan pemindahan nilai privat ada
  di [README backend](../backend/README.md). Kredensial laptop belum dipindahkan.
- Akun MySQL per tugas serta pemeriksaan TLS dipertahankan. Administrator hanya
  dipakai oleh perintah pemeriksaan yang menyebut `--admin`.
- `npm run dev` melakukan build TypeScript lalu menjalankan backend.
- Palet #122B22, #E8EFEA, #F6F6F3 dan Plus Jakarta Sans dengan font offline.
  Widget tetap Material 3 dan state tetap memakai setState.
- Login, katalog grid/filter, detail, form barang, keranjang, pesanan, lowongan,
  serta pesan bansos memakai tema yang sama. Data produk/foto tetap melalui API.
- Tidak menambah tabel, role, fitur lamaran, proses bansos atau status pesanan.

## Pemeriksaan pada sesi ini

| Pemeriksaan | Hasil |
| --- | --- |
| `npm run build` | Lulus |
| `node --test test/koneksi.cjs` | 5 tes lulus; tanpa koneksi DB |
| Guard runner akun/katalog saat `DB_MODE=aiven` | Keduanya menolak sebelum mengakses MySQL |
| `flutter analyze --no-pub` | Tidak ada masalah |
| `flutter test --dart-define=SIMPAN_PRATINJAU=true` | 9 tes lulus |
| Pemeriksaan render layar masuk dan katalog kosong | Teks, tombol dan navigasi diperiksa dari PNG widget |
| Build APK / Pixel 8 | Belum diuji; Android SDK dan emulator tidak tersedia di lingkungan ini |
| Build web | Tidak dilakukan: repo belum memiliki target `web/`; tidak menambahkan platform |
| Laragon utama / Aiven | Tidak diakses; kredensial privat tidak tersedia |

Percobaan build bundle Android terhenti karena Android SDK tidak tersedia.
Tes widget memakai fixture di memori dan tidak mengisi database utama. Hasil
sebelumnya di Pixel 8 bukan pengujian APK baru ini.

## Pratinjau dari widget Flutter

Gambar ini dirender oleh tes widget pada ukuran 393 × 852, bukan screenshot
Pixel 8 dan bukan bukti koneksi MySQL. Katalog ditampilkan kosong agar tidak
mengaku mempunyai produk yang belum dibaca dari database.

[Layar masuk](bukti/ui/masuk.png) · [Katalog kosong](bukti/ui/katalog-kosong.png)

## Mengintegrasikan di laptop

Minta Codex lokal memeriksa branch dan `git diff` sebelum menggabungkan branch
ini. Pertahankan edit manual `backend/package.json`; jika script `dev` sudah ada,
pertahankan yang bekerja. Jangan reset checkout, hapus `.env`, atau menimpa data
Laragon. Setelah nilai privat disatukan sesuai README backend, jalankan:

```powershell
cd C:\Users\Kaysan\UjiLevel\backend
npm.cmd ci
npm.cmd run dev
```

Lalu pada terminal lain:

```powershell
cd C:\Users\Kaysan\UjiLevel\frontend
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 reverse tcp:3000 tcp:3000
C:\flutter\bin\flutter.bat run -d emulator-5554
```

Periksa login ketiga peran, foto ID 2, formulir pegawai, dan pemulihan sesi.
Uji tulis tetap di database terpisah. Jangan menjalankan runner Laragon ketika
`.env` sedang menunjuk Aiven.
