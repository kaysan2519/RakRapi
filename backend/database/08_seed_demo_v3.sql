-- RakRapi V3 — Seed data awal demo idempoten (aman dijalankan berulang tanpa duplikasi)
-- Tidak menimpa akun, transaksi, maupun barang ID 2 (Minyak goreng 1 L) yang sudah ada.

-- 1. Kategori (minimal 9 kategori target; mempertahankan kategori lama id=2 'Minyak Goreng')
INSERT IGNORE INTO kategori (nama) VALUES
  ('Sembako'),
  ('Bumbu dapur'),
  ('Makanan'),
  ('Minuman'),
  ('Sayuran'),
  ('Buah-buahan'),
  ('Protein'),
  ('Kebersihan'),
  ('Kebutuhan rumah');

-- 2. Deskripsi barang lama ID 2 hanya diisi jika masih kosong (stok, harga, foto asli tetap utuh)
UPDATE barang
SET deskripsi = 'Minyak goreng kemasan 1 liter untuk kebutuhan memasak sehari-hari.'
WHERE id = 2 AND (deskripsi = '' OR deskripsi IS NULL);

-- 3. 17 Produk demo tambahan (total >= 18 produk bersama ID 2)
INSERT INTO barang (kategori_id, nama, harga_rupiah, stok, satuan, deskripsi, foto_key)
SELECT k.id, v.nama, v.harga_rupiah, v.stok, v.satuan, v.deskripsi, v.foto_key
FROM (
  SELECT 'Sembako' AS kat, 'Beras premium 5 kg' AS nama, 72000 AS harga_rupiah, 20.000 AS stok, 'pack' AS satuan, 'Beras putih pulen pilihan kemasan 5 kg untuk kebutuhan pokok harian keluarga (data demo).' AS deskripsi, '10000001-0001-4001-8001-000000000001.png' AS foto_key
  UNION ALL SELECT 'Sembako', 'Gula pasir 1 kg', 17500, 25.000, 'kg', 'Gula pasir putih bersih kemasan 1 kg untuk kebutuhan memasak dan minuman (data demo).', '10000002-0002-4002-8002-000000000002.png'
  UNION ALL SELECT 'Bumbu dapur', 'Garam 250 g', 4000, 20.000, 'bungkus', 'Garam dapur halus beryodium kemasan 250 gram untuk melengkapi bumbu masakan (data demo).', '10000003-0003-4003-8003-000000000003.png'
  UNION ALL SELECT 'Bumbu dapur', 'Kecap manis 275 ml', 12500, 15.000, 'botol', 'Kecap manis kedelai hitam kental kemasan botol 275 ml (data demo).', '10000004-0004-4004-8004-000000000004.png'
  UNION ALL SELECT 'Makanan', 'Mi instan goreng', 3500, 50.000, 'bungkus', 'Mi instan goreng siap saji lengkap dengan bumbu dan bawang goreng (data demo).', '10000005-0005-4005-8005-000000000005.png'
  UNION ALL SELECT 'Makanan', 'Biskuit kelapa', 8500, 18.000, 'bungkus', 'Biskuit renyah rasa kelapa gurih cocok untuk camilan keluarga (data demo).', '10000006-0006-4006-8006-000000000006.png'
  UNION ALL SELECT 'Minuman', 'Air mineral 600 ml', 4000, 30.000, 'botol', 'Air mineral segar higienis kemasan botol 600 ml praktis dibawa (data demo).', '10000007-0007-4007-8007-000000000007.png'
  UNION ALL SELECT 'Minuman', 'Susu UHT 250 ml', 7000, 20.000, 'kotak', 'Susu UHT full cream bergizi kemasan kotak 250 ml siap minum (data demo).', '10000008-0008-4008-8008-000000000008.png'
  UNION ALL SELECT 'Sayuran', 'Wortel 500 g', 9000, 10.000, 'pack', 'Wortel segar pilihan kemasan 500 gram untuk sup dan tumisan (data demo).', '10000009-0009-4009-8009-000000000009.png'
  UNION ALL SELECT 'Sayuran', 'Tomat 500 g', 8000, 12.000, 'pack', 'Tomat merah segar kemasan 500 gram siap olah untuk masakan harian (data demo).', '10000010-0010-4010-8010-000000000010.png'
  UNION ALL SELECT 'Buah-buahan', 'Apel 500 g', 18000, 10.000, 'pack', 'Apel merah segar manis kemasan 500 gram pilihan terbaik (data demo).', '10000011-0011-4011-8011-000000000011.png'
  UNION ALL SELECT 'Buah-buahan', 'Pisang 1 sisir', 16000, 8.000, 'sisir', 'Pisang segar matang pohon 1 sisir manis alami (data demo).', '10000012-0012-4012-8012-000000000012.png'
  UNION ALL SELECT 'Protein', 'Telur ayam 1 kg', 29000, 15.000, 'kg', 'Telur ayam negeri segar berkualitas baik dijual per kilogram (data demo).', '10000013-0013-4013-8013-000000000013.png'
  UNION ALL SELECT 'Protein', 'Tahu putih 5 pcs', 8000, 10.000, 'pack', 'Tahu putih lembut segar isi 5 potong siap goreng atau tumis (data demo).', '10000014-0014-4014-8014-000000000014.png'
  UNION ALL SELECT 'Kebersihan', 'Sabun mandi 80 g', 5000, 20.000, 'pcs', 'Sabun mandi batang 80 gram lembut di kulit dengan aroma segar (data demo).', '10000015-0015-4015-8015-000000000015.png'
  UNION ALL SELECT 'Kebersihan', 'Detergen 800 g', 21000, 13.000, 'bungkus', 'Detergen bubuk pembersih noda pakaian kemasan 800 gram (data demo).', '10000016-0016-4016-8016-000000000016.png'
  UNION ALL SELECT 'Kebutuhan rumah', 'Tisu 250 lembar', 12000, 15.000, 'pack', 'Tisu wajah halus isi 250 lembar untuk kebutuhan rumah tangga sehari-hari (data demo).', '10000017-0017-4017-8017-000000000017.png'
) v
JOIN kategori k ON LOWER(k.nama) = LOWER(v.kat)
WHERE NOT EXISTS (SELECT 1 FROM barang b WHERE LOWER(b.nama) = LOWER(v.nama));

-- 4. 3 Lowongan kerja demo
INSERT INTO lowongan (judul, deskripsi, persyaratan, lokasi, info_tambahan, aktif, is_pinned)
SELECT v.judul, v.deskripsi, v.persyaratan, v.lokasi, v.info_tambahan, 1, v.is_pinned
FROM (
  SELECT 'Staff toko' AS judul, 'Menata produk di rak, menjaga kebersihan area toko, dan membantu pelayanan pembeli sehari-hari.' AS deskripsi, 'Jujur, ramah, komunikatif, dan bersedia bekerja dalam shift toko.' AS persyaratan, 'Toko RakRapi (Demo)' AS lokasi, 'Penuh waktu · Toko RakRapi' AS info_tambahan, 1 AS is_pinned
  UNION ALL SELECT 'Kasir', 'Melayani transaksi pembeli, pencatatan pembayaran tunai/transfer, dan penyerahan pesanan di kasir.', 'Teliti berhitung, rapi dalam pencatatan, dan terbiasa melayani pelanggan.', 'Toko RakRapi (Demo)', 'Paruh waktu · Toko RakRapi', 0
  UNION ALL SELECT 'Petugas gudang', 'Memeriksa barang datang dari pemasok, merapikan penyimpanan, dan membantu pencatatan persediaan barang.', 'Sehat jasmani, disiplin, dan teliti dalam memeriksa stok barang.', 'Toko RakRapi (Demo)', 'Penuh waktu · Toko RakRapi', 0
) v
WHERE NOT EXISTS (SELECT 1 FROM lowongan l WHERE LOWER(l.judul) = LOWER(v.judul));

-- 5. 2 Program bansos demo
INSERT INTO program_bansos (nama, deskripsi, jenis_bantuan, persyaratan, kuota, aktif, is_pinned)
SELECT v.nama, v.deskripsi, v.jenis_bantuan, v.persyaratan, v.kuota, 1, 0
FROM (
  SELECT 'Paket sembako warga' AS nama, 'Program demo bantuan paket kebutuhan pokok (beras, minyak goreng, gula) bagi warga sekitar yang membutuhkan.' AS deskripsi, 'Paket kebutuhan pokok (Demo)' AS jenis_bantuan, 'Warga sekitar toko yang membutuhkan; verifikasi dilakukan oleh pemilik toko. Pengajuan demo tidak menjamin penerimaan.' AS persyaratan, 25 AS kuota
  UNION ALL SELECT 'Bantuan kebutuhan sekolah', 'Program demo bantuan perlengkapan alat tulis sekolah untuk keluarga sekitar yang membutuhkan.', 'Perlengkapan sekolah (Demo)', 'Keluarga warga sekitar dengan anak usia sekolah; verifikasi manual oleh pemilik toko.', 15
) v
WHERE NOT EXISTS (SELECT 1 FROM program_bansos pb WHERE LOWER(pb.nama) = LOWER(v.nama));

-- 6. 4 Pengumuman & promo demo
INSERT INTO pengumuman (judul, deskripsi, jenis, info_tambahan, foto_key, aktif, is_pinned)
SELECT v.judul, v.deskripsi, v.jenis, v.info_tambahan, v.foto_key, 1, v.is_pinned
FROM (
  SELECT 'Jadwal layanan toko' AS judul, 'Contoh informasi toko: Buka setiap hari pukul 07.00–21.00. Pesanan diambil langsung di kasir setelah status Siap diambil.' AS deskripsi, 'Informasi toko' AS jenis, 'Informasi toko · Demo' AS info_tambahan, NULL AS foto_key, 0 AS is_pinned
  UNION ALL SELECT 'Stok sembako tersedia', 'Contoh pengumuman katalog: Beras premium, minyak goreng, gula pasir, dan kebutuhan harian tersedia dalam katalog RakRapi.', 'Pengumuman', 'Katalog · Demo', NULL, 0
  UNION ALL SELECT 'Pendaftaran bansos', 'Contoh layanan warga: Baca ketentuan program bantuan sosial dan kirim pengajuan melalui menu Bansos untuk diverifikasi pemilik.', 'Pengumuman', 'Layanan warga · Demo', NULL, 0
  UNION ALL SELECT 'Promo kebutuhan harian', 'Contoh informasi diskon/promo toko: Lihat info promo terbaru sebelum berbelanja. Pengumuman promo tidak mengubah harga katalog secara otomatis.', 'Diskon', 'Promo minggu ini · Demo', '20000001-0001-4001-8001-000000000001.png', 1
) v
WHERE NOT EXISTS (SELECT 1 FROM pengumuman p WHERE LOWER(p.judul) = LOWER(v.judul));

-- 7. Informasi toko tunggal (rekening NULL selama rekening asli belum dikonfigurasi pemilik)
INSERT IGNORE INTO info_toko
  (id, nama_toko, alamat, jam_operasional, kontak, info_pengambilan, nama_bank, nomor_rekening, nama_pemilik_rekening)
VALUES
  (1, 'Toko Sembako RakRapi (Demo)', '', 'Buka setiap hari · 07.00–21.00 (Demo)', '', 'Ambil di kasir toko setelah status pesanan Siap diambil.', NULL, NULL, NULL);
