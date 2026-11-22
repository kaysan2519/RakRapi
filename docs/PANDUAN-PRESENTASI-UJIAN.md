# Panduan Presentasi & Pemahaman Kode RakRapi V3 (XI RPL)

> **Pengembang:** Muhammad Kaysan Ashraf — XI RPL 5 — SMK Taruna Bhakti  
> **Disinkronkan dengan source code V3:** 22 November 2026 (`codex/ui-env-pixel8`)  
> **Tujuan:** Memudahkan siswa menjelaskan setiap bagian kode RakRapi kepada penguji KOKE & MAPIL dengan bahasa sederhana, lokasi file & nomor baris aktual, serta contoh tanya-jawab penguji.

---

## 1. Gambaran Alur Sistem RakRapi V3

```text
[Flutter Android (3 Role: Pembeli/warga, Pegawai, Pemilik)]
   │  HTTP JSON / Multipart + Header "Authorization: Bearer <JWT>"
   ▼
[Express.js REST API — backend/src/app.ts]
   ├─ CORS (cors.middleware.ts)
   ├─ Routes (routes/*.routes.ts) + Middleware Auth & Role (akses.middleware.ts)
   ├─ Upload Multer (upload.middleware.ts) + Validasi (validations/*.validation.ts)
   ├─ Controller (controllers/*.controller.ts) → baca req & kirim JSON status HTTP
   ├─ Service (services/*.service.ts) → query Drizzle ORM + Cloudinary privat
   └─ Error Handler (error.middleware.ts) → ubah error ke JSON yang aman
   ▼
[1 Pool MySQL + Drizzle ORM — db.ts & koneksi.ts]
   └─ MySQL Aiven (TLSv1.3 terverifikasi, akun non-admin rakrapi_app) & Laragon lokal
```

---

## 2. Bedah Kode Inti (Format 9 Poin untuk Penguji)

### 2.1 Konfigurasi Database & Connection Pooling
1. **Nama file:** `koneksi.ts` dan `db.ts`
2. **Lokasi file:** `backend/src/config/koneksi.ts` dan `backend/src/config/db.ts`
3. **Nomor baris aktual:** `koneksi.ts` baris `4–39`; `db.ts` baris `1–7`
4. **Potongan kode inti:**
```ts
// backend/src/config/db.ts (baris 5-7)
export const pool = createPool(opsiKoneksi());
export const db = drizzle(pool);
```
5. **Fungsi kode:** Membaca 1 file `backend/.env` (`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_SSL`, `DB_SSL_CA_BASE64`), mengaktifkan verifikasi TLS CA saat terhubung ke Aiven, lalu membuat 1 connection pool `pool` yang dibungkus Drizzle ORM (`db`).
6. **Alur input → output:** Input dari variabel `.env` → output objek `db` siap dipakai seluruh service.
7. **Hubungan dengan database:** Menjadi pintu tunggal menuju MySQL `rakrapi` (Aiven `TLSv1.3` maupun Laragon lokal).
8. **Contoh pertanyaan penguji:** *Bagaimana cara berpindah dari MySQL Laragon ke MySQL Aiven?*
9. **Jawaban singkat:** Cukup ubah kredensial di satu file `backend/.env` dan set `DB_SSL=true` serta `DB_SSL_CA_BASE64`, tanpa mengubah kode aplikasi.

### 2.2 Struktur Tabel, Primary Key, & Foreign Key
1. **Nama file:** `schema.ts`, `01_skema.sql`–`07_v3_fitur.sql`
2. **Lokasi file:** `backend/src/config/schema.ts` dan `backend/database/07_v3_fitur.sql`
3. **Nomor baris aktual:** `schema.ts` baris `1–169`; `07_v3_fitur.sql` baris `1–116`
4. **Potongan kode inti:**
```ts
// backend/src/config/schema.ts (baris 28-37)
export const barang = mysqlTable("barang", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  kategori_id: int("kategori_id", { unsigned: true }).notNull(),
  nama: varchar("nama", { length: 150 }).notNull(),
  harga_rupiah: int("harga_rupiah", { unsigned: true }).notNull(),
  stok: decimal("stok", { precision: 12, scale: 3 }).notNull(),
  satuan: varchar("satuan", { length: 20 }).notNull(),
  deskripsi: varchar("deskripsi", { length: 500 }).notNull().default(""),
  foto_key: varchar("foto_key", { length: 255 }).notNull(),
});
```
5. **Fungsi kode:** Memetakan 11 tabel MySQL (`users`, `kategori`, `barang`, `pesanan`, `detail_pesanan`, `lowongan`, `lamaran`, `program_bansos`, `pengajuan_bansos`, `pengumuman`, `info_toko`) beserta PK/FK agar query Drizzle terstruktur.
6. **Alur input → output:** Objek tabel dipakai oleh `db.select()`, `db.insert()`, `db.update()`, `db.delete()`.
7. **Hubungan dengan database:** Sinkron 1:1 dengan struktur aktual MySQL Aiven & Laragon (8 Foreign Key + UNIQUE/CHECK constraint).
8. **Contoh pertanyaan penguji:** *Apa fungsi Foreign Key `fk_barang_kategori` dengan `ON DELETE RESTRICT`?*
9. **Jawaban singkat:** Mencegah kategori yang masih dipakai produk terhapus sembarangan sehingga data barang tidak kehilangan kategorinya.

### 2.3 Routes, Controller, Service, Middleware, & Validation
1. **Nama file:** `app.ts`, `*.routes.ts`, `*.controller.ts`, `*.service.ts`, `akses.middleware.ts`, `error.middleware.ts`, `*.validation.ts`
2. **Lokasi file:** `backend/src/app.ts` dan subfolder `routes/`, `controllers/`, `services/`, `middleware/`, `validations/`
3. **Nomor baris aktual:** `app.ts` baris `14–31`; `akses.middleware.ts` baris `5–30`; `error.middleware.ts` baris `20–43`
4. **Potongan kode inti:**
```ts
// backend/src/app.ts (baris 17-29)
app.use("/api/auth", express.json({ limit: "8kb" }), akunRouter);
app.use("/api/kategori", express.json({ limit: "8kb" }), kategoriRouter);
app.use("/api/barang", express.json({ limit: "16kb" }), barangRouter);
app.use("/api/pesanan", express.json({ limit: "64kb" }), pesananRouter);
app.use("/api/lowongan", express.json({ limit: "16kb" }), lowonganRouter);
app.use("/api/bansos", express.json({ limit: "16kb" }), bansosRouter);
app.use("/api/pengumuman", express.json({ limit: "16kb" }), pengumumanRouter);
app.use("/api/pin", pinRouter);
app.use("/api/toko", express.json({ limit: "16kb" }), tokoRouter);
app.use("/api/dashboard", dashboardRouter);
```
5. **Fungsi kode:** Memisahkan tugas secara rapi: Route menentukan URL & hak role, Validation memeriksa format input, Controller membaca request & mengirim status HTTP, Service menjalankan logika + query database, Error Middleware mengubah error menjadi respons JSON aman tanpa stack trace.
6. **Alur input → output:** Request HTTP → Middleware Auth/Role → Controller → Validation → Service → Response JSON (`200`/`201`/`204`/`400`/`401`/`403`/`404`/`409`).
7. **Hubungan dengan database:** Hanya lapisan Service yang menyentuh objek `db` Drizzle ORM.
8. **Contoh pertanyaan penguji:** *Mengapa logika database dipisah dari Controller ke Service?*
9. **Jawaban singkat:** Supaya kode mudah dibaca, mudah diuji, dan satu fungsi service dapat dipakai ulang tanpa mengulang query di controller.

### 2.4 Register, Login, `bcryptjs`, JWT, Middleware Role, & Pemberhentian Pegawai
1. **Nama file:** `akun.routes.ts`, `akun.controller.ts`, `akun.service.ts`, `akses.middleware.ts`, `pengelolaan_toko.dart`
2. **Lokasi file:** `backend/src/routes/akun.routes.ts`, `backend/src/services/akun.service.ts`, `backend/src/middleware/akses.middleware.ts`, `frontend/lib/pengelolaan_toko.dart`
3. **Nomor baris aktual:** `akun.routes.ts` baris `19–31`; `akun.service.ts` baris `59–150`; `akses.middleware.ts` baris `5–26`
4. **Potongan kode inti:**
```ts
// backend/src/routes/akun.routes.ts (baris 20-30)
akunRouter.post("/register", buatAkun("warga"));
akunRouter.get("/pegawai", perluLogin, perluRole("pemilik"), listPegawai);
akunRouter.get("/pegawai/:id", perluLogin, perluRole("pemilik"), detailPegawai);
akunRouter.post("/pegawai", perluLogin, perluRole("pemilik"), buatAkun("pegawai"));
akunRouter.patch("/pegawai/:id/berhentikan", perluLogin, perluRole("pemilik"), nonaktifkanPegawai);
```
```ts
// backend/src/middleware/akses.middleware.ts (baris 17-22)
if (profil.status !== "aktif") {
  res.status(401).json({ pesan: "Akses dicabut. Akun pegawai ini telah diberhentikan." });
  return;
}
```
5. **Fungsi kode:** Register publik selalu menetapkan role `warga` dan menyimpan password dalam bentuk hash `bcryptjs` (cost 12). Login mencocokkan sandi dengan `bcrypt.compare()`, menolak akun berstatus `diberhentikan` (`403`), dan menerbitkan JWT `HS256` (1 jam). `perluLogin` mengecek `status === "aktif"` langsung ke MySQL pada setiap request sehingga token lama pegawai yang baru diberhentikan langsung ditolak (`401`). Pemberhentian hanya mengubah status + menyimpan alasan & tanggal (tanpa `DELETE` permanen) dan memblokir pemberhentian akun pemilik/pembeli (`403`).
6. **Alur input → output:** `PATCH /api/auth/pegawai/:id/berhentikan` `{ alasan }` → `200 { data }` (`status: "diberhentikan"`), selanjutnya login pegawai → `403` dan request token lama → `401`.
7. **Hubungan dengan database:** Membaca/menulis tabel `users` (`email UNIQUE`, `password_hash`, `role`, `status`, `alasan_pemberhentian`, `diberhentikan_pada`).
8. **Contoh pertanyaan penguji:** *Bagaimana jika pegawai yang baru diberhentikan masih memiliki token JWT aktif di HP-nya?*
9. **Jawaban singkat:** Middleware `perluLogin` selalu membaca `status` terbaru dari tabel `users` MySQL pada setiap request, jadi token lama langsung ditolak HTTP `401` dan Flutter otomatis mengeluarkan sesi ke layar Masuk.

### 2.5 CRUD Kategori, Produk (`INNER JOIN`), Pencarian, & Filter
1. **Nama file:** `kategori.service.ts`, `barang.service.ts`, `barang.validation.ts`
2. **Lokasi file:** `backend/src/services/kategori.service.ts`, `backend/src/services/barang.service.ts`
3. **Nomor baris aktual:** `kategori.service.ts` baris `6–19`; `barang.service.ts` baris `8–43`
4. **Potongan kode inti:**
```ts
// backend/src/services/barang.service.ts (baris 8-22)
return db.select({
  id: barang.id, nama: barang.nama, kategori_id: kategori.id,
  nama_kategori: kategori.nama, harga_rupiah: barang.harga_rupiah,
  stok: barang.stok, satuan: barang.satuan, deskripsi: barang.deskripsi,
}).from(barang).innerJoin(kategori, eq(barang.kategori_id, kategori.id));
```
5. **Fungsi kode:** Menggabungkan tabel `barang` dan `kategori` menggunakan `INNER JOIN`, mendukung pencarian teks `?q=` dan filter `?kategori_id=`, serta menghitung `jumlah_produk` pada daftar kategori menggunakan `LEFT JOIN` + `COUNT`.
6. **Alur input → output:** `GET /api/barang?q=beras&kategori_id=3` → `200 { data: [...] }` lengkap dengan `nama_kategori`, `tersedia`, dan `foto_url`.
7. **Hubungan dengan database:** Query relasional pada tabel `barang` dan `kategori`.
8. **Contoh pertanyaan penguji:** *Dari mana asal `nama_kategori` pada kartu dan detail produk?*
9. **Jawaban singkat:** Dari query `INNER JOIN` antara `barang.kategori_id` dan `kategori.id` di `barang.service.ts`.

### 2.6 Upload Foto, Validasi, & Penyimpanan Cloudinary Privat
1. **Nama file:** `upload.middleware.ts`, `foto.validation.ts`, `foto.service.ts`
2. **Lokasi file:** `backend/src/middleware/upload.middleware.ts`, `backend/src/validations/foto.validation.ts`, `backend/src/services/foto.service.ts`
3. **Nomor baris aktual:** `foto.validation.ts` baris `1–258`; `foto.service.ts` baris `66–159`
4. **Potongan kode inti:**
```ts
// backend/src/services/foto.service.ts (baris 95-101 & 130-134)
cloudinary.uploader.upload_stream(
  { public_id: publicId, resource_type: "image", type: "authenticated", overwrite: false }, ...
);
const urlPrivat = cloudinary.utils.private_download_url(publicIdDariKey(key), ekstensi, {
  resource_type: "image", type: "authenticated", expires_at: Math.floor(Date.now() / 1000) + 60,
});
```
5. **Fungsi kode:** Multer menerima 1 file maks 5 MiB di memori, `periksaFoto()` memvalidasi kecocokan MIME dengan penanda biner (*magic bytes*), struktur chunk/marker (termasuk verifikasi `zlib.crc32` bawaan Node.js untuk PNG, marker SOF/SOS/EOI untuk JPEG, dan RIFF/VP8/VP8L/VP8X untuk WebP), serta batas dimensi 16 MP tanpa library pengolah gambar eksternal (`sharp` telah dihapus). Selanjutnya `tulisFoto()` mengunggah ke Cloudinary mode privat (`authenticated`, sekaligus memanfaatkan penolakan gambar tidak valid dari sisi Cloudinary) dan menyimpan nama UUID di kolom `foto_key`.
6. **Alur input → output:** Multipart `foto` → tersimpan privat di Cloudinary → dibaca ulang lewat `/api/<modul>/:id/foto` dengan Bearer JWT.
7. **Hubungan dengan database:** Kolom `foto_key` pada tabel `barang`, `lowongan`, `program_bansos`, dan `pengumuman`.
8. **Contoh pertanyaan penguji:** *Mengapa foto tidak disimpan langsung di database atau URL publik?*
9. **Jawaban singkat:** Menyimpan file biner di database membuat MySQL berat, sedangkan mode privat Cloudinary menjaga agar hanya pengguna login bertoken JWT yang bisa mengakses foto.

### 2.7 Keranjang, Checkout (`Ambil di kasir`), Pembayaran, & Pengurangan Stok
1. **Nama file:** `keranjang.dart`, `pesanan.service.ts`, `pesanan.routes.ts`
2. **Lokasi file:** `frontend/lib/keranjang.dart` dan `backend/src/services/pesanan.service.ts`
3. **Nomor baris aktual:** `pesanan.service.ts` baris `29–205`; `keranjang.dart` baris `296–450`
4. **Potongan kode inti:**
```ts
// backend/src/services/pesanan.service.ts (baris 144-169)
await db.transaction(async tx => {
  const [data] = await tx.select().from(pesanan).where(eq(pesanan.id, id)).for("update");
  if (data.status === "Dikonfirmasi") return;
  for (const r of rincian) {
    const [b] = await tx.select().from(barang).where(eq(barang.id, r.barang_id)).for("update");
    if (Number(b.stok) < Number(r.jumlah)) throw new KesalahanKatalog(409, `Stok ${b.nama} tidak cukup.`);
    await tx.update(barang).set({ stok: sql`${barang.stok} - ${r.jumlah}` }).where(eq(barang.id, b.id));
  }
  await tx.update(pesanan).set({ status: "Dikonfirmasi" }).where(eq(pesanan.id, id));
});
```
5. **Fungsi kode:** Menghitung ulang total belanja di server dengan `BigInt` dari harga database (mengabaikan total dari client), mencegah pesanan ganda lewat `kunci_kirim`, memblokir transfer bank bila rekening toko belum diatur, memisahkan `status` pesanan (`Menunggu konfirmasi` → `Dikonfirmasi` → `Siap diambil` → `Selesai`) dan `status_pembayaran` (`Belum dibayar` → `Sudah dibayar`), serta melarang status `Selesai` sebelum pembayaran diverifikasi pegawai/pemilik.
6. **Alur input → output:** `POST /api/pesanan` (`201`) → `PATCH /konfirmasi` (potong stok) → `PATCH /siap` → `PATCH /bayar` → `PATCH /selesai`.
7. **Hubungan dengan database:** Tabel `pesanan`, `detail_pesanan`, `barang`, dan `info_toko`.
8. **Contoh pertanyaan penguji:** *Bagaimana jika dua pegawai menekan Konfirmasi pada pesanan yang sama secara bersamaan?*
9. **Jawaban singkat:** Karena memakai `db.transaction()` dan `.for("update")`, pegawai kedua menunggu kunci selesai lalu melihat status sudah `Dikonfirmasi`, sehingga stok tidak mungkin terpotong dua kali.

### 2.8 Lowongan, Bansos, Pengumuman/Diskon, & Pin Informasi Prioritas
1. **Nama file:** `lowongan.service.ts`, `bansos.service.ts`, `pengumuman.service.ts`, `info.service.ts`, `layanan_info.dart`
2. **Lokasi file:** `backend/src/services/{lowongan,bansos,pengumuman,info}.service.ts` dan `frontend/lib/layanan_info.dart`
3. **Nomor baris aktual:** `lowongan.service.ts` baris `133–180`; `bansos.service.ts` baris `143–245`; `info.service.ts` baris `28–80`
4. **Potongan kode inti:**
```ts
// backend/src/services/info.service.ts (baris 28-45)
const [daftarLow, daftarBan, daftarPeng] = await Promise.all([
  db.select().from(lowongan).where(hanyaDipin ? and(eq(lowongan.aktif, true), eq(lowongan.is_pinned, true)) : undefined),
  db.select().from(programBansos).where(hanyaDipin ? and(eq(programBansos.aktif, true), eq(programBansos.is_pinned, true)) : undefined),
  db.select().from(pengumuman).where(hanyaDipin ? and(eq(pengumuman.aktif, true), eq(pengumuman.is_pinned, true)) : undefined),
]);
```
5. **Fungsi kode:** Mengelola CRUD & verifikasi pengajuan Lowongan/Bansos (anti-duplikat `UNIQUE`, validasi kuota transaksional, tanpa NIK/penghasilan fiktif), Pengumuman & Diskon (diskon hanya informasi promo, tidak mengubah harga katalog), serta menggabungkan item `is_pinned = true` lintas 3 tabel ke bagian atas Beranda Pembeli tanpa duplikasi data.
6. **Alur input → output:** Pemilik toggle `PATCH /:modul/:id/pin` → tersimpan di MySQL → Pembeli memanggil `GET /api/pin` dan langsung melihat kartu prioritas beserta fotonya.
7. **Hubungan dengan database:** Tabel `lowongan`, `lamaran`, `program_bansos`, `pengajuan_bansos`, `pengumuman`, `info_toko`.
8. **Contoh pertanyaan penguji:** *Apakah data lowongan diduplikasi saat pemilik menekan Pin ke beranda?*
9. **Jawaban singkat:** Tidak. Kita cukup mengubah kolom boolean `is_pinned` menjadi `true` pada tabel asalnya, lalu `GET /api/pin` membaca item terpin dari ketiga tabel tersebut.

### 2.9 Integrasi Flutter (API Client, Sesi JWT, 3 Dashboard Role)
1. **Nama file:** `api.dart`, `main.dart`, `beranda_pembeli.dart`, `dashboard_pengelola.dart`
2. **Lokasi file:** `frontend/lib/`
3. **Nomor baris aktual:** `api.dart` baris `16–80`; `main.dart` baris `37–132`; `dashboard_pengelola.dart` baris `150–195`
4. **Potongan kode inti:**
```dart
// frontend/lib/api.dart (baris 18-21 & 32-35)
this.alamat = const String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:3000/api');
if (privat && tokenPermintaan != null) {
  request.headers['Authorization'] = 'Bearer $tokenPermintaan';
}
```
5. **Fungsi kode:** Menyimpan token JWT dengan `SharedPreferencesAsync`, memulihkan sesi via `GET /api/auth/me`, mengarahkan 3 role dari satu layar Login ke `BerandaWarga` (5 tab) atau `ShellPengelola` (4 tab), serta mengirim semua request melalui `package:http` tanpa data dummy fallback.
6. **Alur input → output:** Interaksi pengguna di Flutter → HTTP Request ke Express → Response JSON aktual MySQL Aiven → `setState` / `FutureBuilder` memperbarui layar.
7. **Hubungan dengan database:** 100% data (akun, katalog, pesanan, pin, info toko, statistik dashboard) diambil langsung dari REST API yang membaca MySQL Aiven.
8. **Contoh pertanyaan penguji:** *Bagaimana jika nanti backend sudah di-hosting ke internet dengan HTTPS?*
9. **Jawaban singkat:** Tidak perlu merombak kode Flutter; cukup build ulang memakai `--dart-define=API_URL=https://domain-anda/api`.

---

## 3. Penjelasan Teknik Lanjutan & Risiko Jika Dihilangkan

| Teknik Lanjutan | Lokasi Penggunaan | Alasan Penggunaan | Risiko Jika Dihilangkan |
|---|---|---|---|
| **Database Transaction** (`db.transaction`) | `pesanan.service.ts`, `bansos.service.ts` | Memastikan seluruh operasi (cek stok + potong stok + ubah status) berhasil semua atau batal semua (*atomic*). | Jika barang ke-2 stoknya habis, barang ke-1 terlanjur terpotong sehingga stok rusak. |
| **Row Locking** (`.for("update")` / `.for("share")`) | `pesanan.service.ts`, `bansos.service.ts` | Mengunci baris pesanan, barang, atau kuota bansos selama transaksi berjalan. | *Race condition*: 2 petugas mengonfirmasi bersamaan dapat memotong stok 2 kali atau melampaui kuota bansos. |
| **`BigInt` Perhitungan Uang** | `pesanan.service.ts`, `keranjang.dart` | Menghitung subtotal & total rupiah presisi bulat tanpa error *floating-point* JavaScript. | Pembulatan `float` bisa selisih Rp1 atau salah hitung pada jumlah pecahan `kg`. |
| **Idempotency (`kunci_kirim`)** | `pesanan.service.ts`, `keranjang.dart` | Kunci 32 hex unik per keranjang + `UNIQUE (warga_id, kunci_kirim)`. | Ketukan ganda saat sinyal lambat akan membuat 2 pesanan identik. |
| **Unique & Check Constraints** | `01_skema.sql`–`07_v3_fitur.sql` | Menjaga email/kategori unik, stok `>= 0`, kuota `>= 1`, dan anti-duplikat lamaran/bansos di tingkat database. | Data korup (stok minus, lamaran ganda) tetap bisa masuk jika ada bug di aplikasi. |
| **Validasi Biner Foto Bawaan Node.js (`Buffer` + `zlib.crc32`)** | `foto.validation.ts` (`1–258`) | Memastikan file benar-benar gambar JPG/PNG/WebP valid ≤ 5 MiB & ≤ 16 MP (magic bytes, chunk/CRC32 PNG, marker SOF/SOS/EOI JPEG, RIFF/VP8/VP8L/VP8X WebP) tanpa library eksternal (`sharp` telah dihapus), ditambah verifikasi server-side Cloudinary saat mode produksi aktif. | File kosong, file menyamar sebagai `.png`, MIME palsu, dimensi > 16 MP, atau struktur gambar korup bisa lolos masuk ke penyimpanan. *(Catatan jujur: pemeriksaan struktur biner tidak setara dekode piksel penuh seperti libvips pada mode lokal tanpa Cloudinary.)* |
| **Non-Destructive Migration** | `07_v3_fitur.sql`, `08_seed_demo_v3.sql` | Menambah kolom & tabel baru tanpa `DROP TABLE` / `TRUNCATE`. | Data asli toko (akun, produk ID 2, riwayat pesanan) akan hilang terhapus. |

---

## 4. Transparansi Data Operasional Saat Presentasi (Referensi Nyata vs Simulasi)

Jika penguji bertanya *"Apakah katalog produk, lowongan kerja, dan program bansos di RakRapi ini data sungguhan?"*, jawab secara jujur dan terstruktur:

- **Berbasis referensi pasar nyata:** 20 produk sembako lintas 10 kategori (masing-masing 2 produk) memakai nama produk dan merek yang benar-benar beredar di Indonesia, kisaran harga acuan pasar Depok/Jabodetabek, serta 30 foto produk & layanan asli di Cloudinary privat (3 foto asli toko ID 2/9/13 utuh + foto produk/operasional sah dari Open Food Facts, Wikimedia Commons, dan packshot resmi merek).
- **Berstatus simulasi proyek UMKM Uji Level:** jumlah stok, skenario 3 lowongan kerja (`Staff Toko`, `Kasir`, `Petugas Gudang`), 3 program bantuan sosial warga (tercantum tegas bukan program pemerintah dan tidak mengumpulkan NIK/penghasilan fiktif), promo paket dapur kasir (harga katalog tetap reguler), serta alamat/kontak layanan kasir di `info_toko` (rekening transfer dinonaktifkan karena tidak memakai rekening fiktif).
