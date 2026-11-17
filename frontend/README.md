# RakRapi untuk Android

Jalankan MySQL Laragon dan backend RakRapi di port 3000. Di PowerShell, buka emulator Pixel 8 jika belum aktif, lalu tunggu sampai layar Android siap.

```powershell
Set-Location C:\Users\Kaysan\UjiLevel\frontend
C:\flutter\bin\flutter.bat emulators --launch Pixel_8
```

Untuk menjalankan aplikasi pada emulator yang sudah siap:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 reverse tcp:3000 tcp:3000
C:\flutter\bin\flutter.bat run -d emulator-5554
```

Penerusan port membuat `http://127.0.0.1:3000/api` di Android mengarah ke backend laptop. Pada perangkat Android lain, gunakan ID yang ditampilkan oleh `flutter devices` pada kedua perintah. Alamat API juga bisa diatur lewat `--dart-define=API_URL=...`.

Masuk sebagai pemilik, buka **Tambah barang**, lalu pilih kategori. **Tambah kategori** di formulir langsung memilih kategori yang baru disimpan. Isi nama, harga rupiah per satuan dan stok, pilih botol atau kg, lalu pilih foto JPEG/PNG dari galeri (maksimal 5 MiB dan 16 megapiksel). Setelah **Simpan**, aplikasi membuka detail berdasarkan ID dari API. Untuk membaca barang sebagai pegawai, kembali ke daftar, pilih **Keluar**, lalu masuk dengan akun pegawai.

Jika foto masih ada di laptop, perintah PowerShell berikut menyalin satu foto ke album **RakRapi** pada emulator. Saat diminta, masukkan jalur lengkap file JPEG atau PNG. Di pemilih foto Android, album berada di **Collections → From this device → RakRapi**.

```powershell
$foto = Get-Item -LiteralPath ((Read-Host "Lokasi foto asli").Trim('"'))
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$tujuan = "/sdcard/Pictures/RakRapi/$([guid]::NewGuid())$($foto.Extension)"
& $adb -s emulator-5554 shell mkdir -p /sdcard/Pictures/RakRapi
& $adb -s emulator-5554 push $foto.FullName $tujuan
& $adb -s emulator-5554 shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://$tujuan"
```

Alur kode dimulai di `lib/main.dart` untuk masuk dan memulihkan sesi. Buka `lib/katalog.dart` untuk daftar, detail dan foto privat, `lib/form_barang.dart` untuk isian dan pratinjau, serta `lib/api.dart` untuk permintaan HTTP dan pengiriman foto. Token sesi disimpan lewat SharedPreferences dan dihapus saat keluar.

### Mencoba tiga peran

Gunakan **Daftar sebagai warga** pada layar Masuk untuk membuat akun pribadi. Akun warga membuka **Katalog** dan bisa memilih tab **Lowongan** atau **Bansos**. Untuk membuat akun pegawai, masuk sebagai pemilik dan buka **Menu pemilik (⋮) → Tambah pegawai** pada daftar barang. Pilih **Keluar** untuk berganti akun. Pegawai memakai formulir barang yang sama dengan pemilik dan memilih kategori yang sudah tersedia. Hapus barang, pengelolaan kategori dan lowongan, serta tambah pegawai hanya tersedia untuk pemilik. Saat aplikasi dibuka kembali, sesi yang masih berlaku membuka Katalog.

### Uji pengembang

`flutter test` menjalankan tes formulir tanpa MySQL. Untuk menguji ketiga peran dan katalog dari layar emulator, aktifkan API utama dan Pixel 8, siapkan satu foto uji di galeri, lalu jalankan dari PowerShell:

```powershell
Set-Location C:\Users\Kaysan\UjiLevel\backend
node --env-file=.env test/akun.cjs emulator-5554
$env:RAKRAPI_EMULATOR = 'emulator-5554'
node --env-file=.env --test test/katalog.cjs
Remove-Item Env:RAKRAPI_EMULATOR
```

Kedua pengujian menyiapkan database sementara dan membersihkannya setelah selesai. Pada tes katalog, pegawai membaca ID 2 di API utama. Pemilik menambahkan barang di API uji, mengubah harga, memeriksa konfirmasi hapus kategori dan pesan kategori terpakai. Pilih foto uji kemudian tekan **Done** jika pemilih Android menampilkannya. Tes kembali masuk sebagai pegawai dan membaca hasil perubahan.
