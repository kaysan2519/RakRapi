# Perubahan UI dan konfigurasi RakRapi

Dasar: commit `fe89281` pada `feat/penuntasan-katalog`.
Paket dibuat pada branch `feat/ui-env-sederhana`, kemudian commit `8715f5b`
diintegrasikan sebagai `73881e9` pada branch lokal `codex/ui-env-pixel8`.
Perubahan manual `backend/package.json` dipertahankan.

## Hasil

- Satu template `.env.example`, satu konfigurasi aktif `backend/.env` untuk API,
  pemeriksaan Aiven, dan sandi demo opsional. Panduan pemindahan nilai privat ada
  di [README backend](../backend/README.md). Konfigurasi lokal sudah disatukan
  dengan salinan privat sebagai cadangan; nilai koneksi lama tidak berubah.
- Akun MySQL per tugas serta pemeriksaan TLS dipertahankan. Administrator hanya
  dipakai oleh perintah pemeriksaan yang menyebut `--admin`.
- `npm run dev` melakukan build TypeScript lalu menjalankan backend.
- Palet #122B22, #E8EFEA, #F6F6F3 dan Plus Jakarta Sans dengan font offline.
  Widget tetap Material 3 dan state tetap memakai setState.
- Login, katalog grid/filter, detail, form barang, keranjang, pesanan, lowongan,
  serta pesan bansos memakai tema yang sama. Data produk/foto tetap melalui API.
- Tidak menambah tabel, role, fitur lamaran, proses bansos atau status pesanan.

## Pemeriksaan awal oleh pembuat paket

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

## Integrasi dan uji lokal — 18 November 2026

Konfigurasi aktif adalah Laragon pada port 3306; API pada port 3000.
Nilai `.env` lama dibandingkan dengan cadangan dan tetap sama. Nilai demo
ditambahkan dari konfigurasi privat lama tanpa menampilkan sandi. `.env`,
cadangan, foto unggahan, dan salinan APK uji tetap diabaikan Git.
Konfigurasi Aiven lama disimpan sampai koneksi Aiven benar-benar teruji.

| Pemeriksaan lokal | Hasil aktual |
| --- | --- |
| `npm ci` / build backend | Lulus; audit 0 kerentanan |
| Tes konfigurasi / tes katalog HTTP | 5 / 5 tes lulus |
| Tes akun dan pesanan HTTP di database terpisah | Lulus: register 201, duplikat 409, hak akses 401/403, lowongan 201/204, pesanan dan transaksi stok |
| `flutter test --no-pub` | 9 tes lulus |
| `flutter analyze --no-pub` | Tidak ada masalah, termasuk tes integrasi yang diperbarui |
| Build dan tes UI Pixel 8 | Lulus; `Pixel_8`, `emulator-5554`; APK uji memakai paket terpisah `com.example.rakrapi.qa` |
| API utama | Health 200 untuk `rakrapi`; login dan profil pegawai 200; detail dan foto ID 2 200 |
| Data utama | Tetap 1 barang; ID 2 Rp19.000, 12 botol; `foto_key` tetap; SHA-256 foto identik |
| APK utama | Terpasang dengan `adb install -r`; SHA-256 APK terpasang sama dengan hasil build |
| Buka ulang APK utama | Sesi pegawai pulih setelah `am force-stop`; katalog ID 2 dan fotonya tampil tanpa login ulang |

Tes HTTP pesanan memeriksa harga tersimpan, jumlah botol/kg, stok tidak cukup
(409 tanpa perubahan parsial), konfirmasi berulang/bersamaan (stok berkurang
sekali), serta pesanan warga lain (404). Semua percobaan tulis memakai database
sementara yang dibersihkan oleh runner; katalog utama hanya dibaca.

**Yang diamati pada Pixel 8:** warga mendaftar dan masuk ke katalog; sesi
warga, pegawai, dan pemilik dipulihkan dengan membangun ulang widget aplikasi
dari penyimpanan sesi. Pemilik menambah pegawai serta membuka/menutup lowongan.
Warga memuat ulang lowongan dan lowongan tertutup tidak muncul lagi. Pegawai
menambah barang berfoto, lalu mengubah harga 25.000 menjadi 26.000 tanpa memilih
foto baru; byte foto dari API tetap identik.

Warga mengirim pesanan 2,125 kg dengan total Rp55.250. Pegawai mengonfirmasi;
stok uji berkurang dari 8 menjadi 5,875 kg. Sesudah sesi warga dipulihkan,
Pesanan saya menampilkan Dikonfirmasi. Terakhir, pegawai membaca ID 2 di API
Laragon utama: Rp19.000, 12 botol, dan foto minyak tampil.

Screenshot aktual perangkat: [katalog warga](bukti/ui-pixel8/katalog-warga.png),
[form pegawai](bukti/ui-pixel8/form-pegawai-pixel8.png),
[keranjang](bukti/ui-pixel8/keranjang-warga.png),
[pesanan masuk](bukti/ui-pixel8/pesanan-masuk.png), dan
[detail ID 2 Laragon](bukti/ui-pixel8/detail-id2-laragon.png).
Empat gambar pertama memakai data database uji, bukan katalog utama.
Sesudah tes terisolasi, APK utama juga dibuka kembali memakai API Laragon:
[katalog pegawai setelah buka ulang](bukti/ui-pixel8/katalog-laragon-pegawai.png).

**Batas pengujian:** pemilih berkas Android disimulasikan pada tes integrasi;
form, unggah file PNG, API, MySQL, dan pembacaan foto berjalan nyata. Interaksi
galeri Android dengan foto pilihan pengguna belum diuji ulang pada APK ini.
Aiven belum tersambung dan tidak menerima migration, seed, atau pesanan demo.
Tes UI dan pengambilan screenshot terakhir selesai dengan exit code 0.

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
