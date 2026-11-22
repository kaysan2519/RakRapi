# Panduan Penjelasan Kode RakRapi untuk Presentasi Ujian (XI RPL)

> **Pengembang:** Muhammad Kaysan Ashraf — XI RPL 5 — SMK Taruna Bhakti  
> **Tujuan panduan:** Membantu menjelaskan alur aplikasi RakRapi dari Flutter → Express REST API → Drizzle ORM → MySQL dengan bahasa sederhana dan lokasi file yang tepat.

---

## 1. Gambaran Besar Alur Data RakRapi

```text
[Flutter Android]
   │  Kirim HTTP JSON / Multipart + header "Authorization: Bearer <JWT>"
   ▼
[Express.js Backend — backend/src/app.ts]
   ├─ 1. CORS (middleware/cors.middleware.ts)
   ├─ 2. Routes (routes/*.routes.ts) + Middleware Auth & Role (middleware/akses.middleware.ts)
   ├─ 3. Controller (controllers/*.controller.ts) → baca req.params / req.body / req.file
   ├─ 4. Validasi (validations/*.validation.ts) → tolak input salah (400 / 413 / 415)
   ├─ 5. Service (services/*.service.ts) → jalankan query Drizzle ORM & Cloudinary privat
   └─ 6. Error Middleware (middleware/error.middleware.ts) → ubah error menjadi JSON status HTTP
   ▼
[1 Pool MySQL + Drizzle ORM — backend/src/config/db.ts & koneksi.ts]
   ├─ Lokal (Laragon): DB_SSL=false
   └─ Cloud (Aiven):   DB_SSL=true + DB_SSL_CA_BASE64 (TLSv1.3 terverifikasi)
```

---

## 2. Peta File Utama & Fungsi Singkatnya

### A. Konfigurasi Backend (Paling Sering Ditanya Penguji)
1. **`backend/.env`** *(tidak diunggah ke Git; template di `backend/.env.example`)*
   - Menyimpan seluruh pengaturan dalam **1 file sederhana**: `PORT`, koneksi MySQL (`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_SSL`, `DB_SSL_CA_BASE64`), `JWT_SECRET`, `JWT_EXPIRES_IN=1h`, `BCRYPT_SALT_ROUNDS=12`, kredensial `CLOUDINARY_*`, dan `CORS_ORIGIN`.
2. **`backend/src/config/koneksi.ts`** *(baris 1–39)*
   - Menyusun opsi koneksi `mysql2`.
   - Jika `DB_SSL=false` → koneksi langsung ke MySQL Laragon lokal.
   - Jika `DB_SSL=true` → men-decode sertifikat CA dari `DB_SSL_CA_BASE64` dan mengaktifkan `ssl: { ca, rejectUnauthorized: true, verifyIdentity: true }` agar koneksi ke Aiven selalu terenkripsi TLS dan terverifikasi.
3. **`backend/src/config/db.ts`** *(baris 1–7)*
   - Membuat **1 connection pool MySQL (`pool`)** dan membungkusnya dengan **1 instance Drizzle ORM (`db = drizzle(pool)`)** yang dipakai bersama oleh seluruh service.
4. **`backend/src/config/schema.ts`** *(baris 1–54)*
   - Memetakan 6 tabel MySQL (`users`, `kategori`, `barang`, `lowongan`, `pesanan`, `detail_pesanan`) ke objek TypeScript Drizzle ORM agar query aman dan terstruktur.

### B. Autentikasi JWT, `bcryptjs`, & 3 Role
5. **`backend/src/services/akun.service.ts`** *(baris 1–118)*
   - **`daftarkanAkun()`** (baris 22–36): meng-hash sandi dengan `bcrypt.hash(password, saltRounds())` lalu menyimpan akun ke tabel `users` via `db.insert(users)`. Role ditentukan oleh route (`"warga"` untuk register publik, `"pegawai"` khusus rute pemilik), bukan dari input bebas pengguna.
   - **`periksaLogin()`** (baris 38–50): mencari email di tabel `users`, mencocokkan sandi dengan `bcrypt.compare()`, lalu menerbitkan token JWT melalui `buatToken()`.
   - **`buatToken()`** (baris 84–91): memanggil `jwt.sign({}, jwtSecret(), { algorithm: "HS256", subject: String(id), issuer: "rakrapi", expiresIn: "1h" })`.
   - **`idPenggunaDariToken()`** (baris 93–118): membaca header `Authorization: Bearer <token>`, memverifikasi tanda tangan & masa berlaku token memakai `jwt.verify()`, dan mengembalikan ID pengguna.
6. **`backend/src/middleware/akses.middleware.ts`** *(baris 1–30)*
   - **`perluLogin`** (baris 5–20): memverifikasi JWT lalu mengambil **profil dan role terbaru dari tabel `users` MySQL** (`ambilProfil(idPengguna)`). Jika token tidak sah/kedaluwarsa → HTTP `401`.
   - **`perluRole(...diizinkan)`** (baris 22–30): mengecek apakah `res.locals.user.role` termasuk role yang diizinkan pada endpoint tersebut. Jika tidak → HTTP `403`.

### C. Katalog, Relasi `INNER JOIN`, & Foto Privat Cloudinary
7. **`backend/src/routes/barang.routes.ts`** → **`controllers/barang.controller.ts`** → **`services/barang.service.ts`**
   - **`barangDenganKategori()`** (`barang.service.ts` baris 8–21): menggabungkan tabel `barang` dan `kategori` menggunakan `.innerJoin(kategori, eq(barang.kategori_id, kategori.id))` sehingga response langsung membawa `nama_kategori` (contoh: *Minyak goreng 1 L* → *Minyak Goreng*).
   - **`simpanBarang()`** (`barang.service.ts` baris 43–96): memvalidasi foto terlebih dahulu (`siapkanFoto`), memvalidasi data barang, menyimpan foto, lalu menjalankan `INSERT`/`UPDATE` ke MySQL. Jika DB gagal, foto yatim otomatis dibersihkan.
8. **`backend/src/services/foto.service.ts`** *(baris 1–176)*
   - Menyimpan dan membaca foto produk secara **privat** (`type: "authenticated"`) di Cloudinary bila kredensial `CLOUDINARY_*` terisi (atau folder lokal bila `UPLOAD_DIR` dipakai saat pengujian lokal).
   - Saat aplikasi meminta `GET /api/barang/:id/foto` dengan Bearer token, server membuat `private_download_url` bertanda tangan sementara (berlaku 60 detik), mengambil byte asli dari Cloudinary, lalu mengirimkannya ke Flutter.
9. **`backend/src/validations/foto.validation.ts`** *(baris 1–61)*
   - Memeriksa batas ukuran 5 MiB (`413`), kecocokan MIME & penanda file PNG/JPEG, batas 16 megapiksel, serta dekode gambar ketat tanpa mengubah byte foto asli.

### D. Pesanan & Transaksi Stok
10. **`backend/src/services/pesanan.service.ts`** *(baris 1–95)*
    - **`buatPesanan()`**: menyimpan pesanan dan menyalin harga satuan saat itu ke `detail_pesanan` di dalam satu transaksi `db.transaction()`.
    - **`konfirmasiPesanan()`**: memakai transaksi database (`db.transaction()` + `.for("update")`) untuk mengecek seluruh stok item sebelum menguranginya. Jika satu barang stoknya kurang, seluruh transaksi otomatis dibatalkan (*rollback*, HTTP `409`) sehingga stok tidak pernah terpotong sebagian.

### E. Frontend Flutter (Mengikuti 4 Artikel Medium Guru `divdannn`)
11. **`frontend/lib/main.dart`**: menyimpan & memulihkan token JWT dengan `SharedPreferencesAsync`, mengecek sesi ke `GET /api/auth/me`, lalu mengarahkan layar sesuai role (`BerandaWarga` atau `DaftarBarang` pemilik/pegawai).
12. **`frontend/lib/api.dart`**: membungkus seluruh permintaan `package:http` (JSON & `MultipartRequest` foto) dan menyisipkan header `Authorization: Bearer <token>` pada setiap endpoint privat.
13. **`frontend/lib/form_barang.dart`**: memilih foto dengan `image_picker` (`ImagePicker().pickImage`), menampilkan pratinjau, lalu mengirim form tambah/ubah barang ke API.

---

## 3. Contoh Pertanyaan Penguji & Cara Menjawab Singkat

1. **Mengapa hanya memakai 1 pool database di `db.ts`, apakah hak akses 3 role tetap aman?**
   - *Jawab:* Aman, karena pembatasan role (`pemilik`, `pegawai`, `warga`) dijalankan di Express lewat middleware `perluLogin` dan `perluRole(...)` di `akses.middleware.ts`, yang mengecek JWT lalu membaca role terbaru langsung dari tabel `users`. Akun database production di Aiven juga tetap akun aplikasi terbatas `rakrapi_app` (bukan `avnadmin`).
2. **Dari mana asal `nama_kategori` pada layar detail barang?**
   - *Jawab:* Dari query `INNER JOIN` antara `barang.kategori_id` dan `kategori.id` di fungsi `barangDenganKategori()` pada `backend/src/services/barang.service.ts` baris 8–21.
3. **Apa yang terjadi jika warga mengirim `"role": "pemilik"` saat register?**
   - *Jawab:* Diabaikan. Route `POST /api/auth/register` (`akun.routes.ts` baris 12) memanggil `buatAkun("warga")` sehingga server selalu menyimpan role `warga`.
4. **Bagaimana jika token JWT dipalsukan atau sudah lebih dari 1 jam?**
   - *Jawab:* `jwt.verify()` di `akun.service.ts` menolak token dan `perluLogin` mengembalikan HTTP `401`, lalu Flutter di `main.dart` menghapus token dan mengembalikan pengguna ke layar Masuk.
5. **Bagaimana aplikasi menjaga kategori yang masih dipakai barang agar tidak terhapus?**
   - *Jawab:* Tabel `barang` memiliki Foreign Key `fk_barang_kategori ... ON DELETE RESTRICT` ke `kategori.id`. Saat MySQL menolak hapus (`ER_ROW_IS_REFERENCED`), `error.middleware.ts` mengembalikan HTTP `409` dengan pesan yang jelas.
6. **Mengapa foto barang tidak langsung memakai URL publik?**
   - *Jawab:* Foto disimpan dengan mode privat (`authenticated`) di Cloudinary dan hanya disajikan melalui endpoint `GET /api/barang/:id/foto` yang mewajibkan token JWT.
7. **Bagaimana mencegah stok minus atau terpotong dua kali saat konfirmasi pesanan?**
   - *Jawab:* `konfirmasiPesanan()` di `pesanan.service.ts` membungkus pengecekan stok, pengurangan stok, dan perubahan status ke dalam satu transaksi MySQL (`db.transaction()`). Jika stok salah satu barang tidak cukup, semua perubahan dibatalkan (*rollback*).
8. **Bagaimana cara ganti koneksi antara Laragon lokal dan Aiven?**
   - *Jawab:* Cukup ubah nilai di satu file `backend/.env` (`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_SSL=true`, dan `DB_SSL_CA_BASE64`) tanpa mengubah source code.
9. **Bagaimana cara menjelaskan `bcrypt` ketika `BCRYPT_SALT_ROUNDS` diubah dari 10 ke 12?**
   - *Jawab:* `bcrypt.compare()` membaca jumlah salt rounds yang tersimpan di dalam string hash lama, sehingga akun lama tetap bisa login normal sementara akun baru otomatis memakai 12 rounds.
