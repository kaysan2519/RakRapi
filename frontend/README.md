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

Gunakan **Daftar sebagai warga** pada layar Masuk untuk membuat akun pribadi. Masuk dengan akun itu untuk membuka halaman **Bansos**. Untuk membuat akun pegawai, masuk sebagai pemilik dan buka **Menu pemilik (⋮) → Tambah pegawai** pada daftar barang. Pilih **Keluar** untuk berganti akun. Pegawai dapat membuka katalog dan foto, sedangkan pemilik juga dapat mengelola barang. Saat aplikasi dibuka kembali, sesi yang masih berlaku membuka halaman sesuai peran dari API.

### Uji pengembang

`flutter test` menjalankan tes formulir tanpa MySQL. Untuk tes perangkat, siapkan API kedua pada port terpisah dengan database katalog dan direktori unggahan sementara. Database itu harus memiliki nol barang dan tepat satu kategori penanda bernama `QA-` diikuti 16 digit heksadesimal unik. Login memakai dua akun demo lokal. Galeri emulator perlu satu foto uji.

Di folder ini, jalankan `flutter test integration_test/alur_barang_test.dart -d emulator-5554`. Di terminal kedua, jalankan `node integration_test/kirim_sesi.cjs emulator-5554 PORT_UJI NAMA_PENANDA` dengan nilai dari lingkungan uji tersebut. Pilih foto uji ketika galeri terbuka. Tes membaca minyak goreng dari API utama dan memeriksa penanda sebelum menulis ke API kedua.
