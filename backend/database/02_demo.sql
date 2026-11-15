-- Demo MySQL untuk RakRapi. Jalankan di sesi mysql baru setelah skema siap.
-- Khusus file demo ini, gunakan opsi --force agar SELECT sesudah galat 1451
-- tetap berjalan. Galat yang diharapkan hanya satu: penolakan DELETE kategori.
-- Semua perubahan data contoh berada dalam satu transaksi.
USE rakrapi;
START TRANSACTION;

-- Nama unik memisahkan kategori demo dari kategori milik toko.
INSERT INTO kategori (nama)
VALUES (CONCAT('Minyak Goreng (uji ', UUID(), ')'));
SET @id_kategori_uji = IF(ROW_COUNT() = 1, LAST_INSERT_ID(), NULL);

-- foto_key hanya contoh teks untuk uji database. Foto fisik belum dibuat.
INSERT INTO barang (kategori_id, nama, harga_rupiah, stok, satuan, foto_key)
VALUES (@id_kategori_uji, 'Minyak goreng 1 L', 19000, 12, 'botol', 'contoh/minyak-1-l.jpg');
SET @id_barang_uji = IF(ROW_COUNT() = 1, LAST_INSERT_ID(), NULL);

-- 1. INNER JOIN mengambil nama kategori melalui FK pada barang.
SELECT b.nama AS nama_barang, k.nama AS nama_kategori,
       b.harga_rupiah, b.stok, b.satuan
FROM barang AS b
INNER JOIN kategori AS k ON k.id = b.kategori_id
WHERE b.id = @id_barang_uji AND k.id = @id_kategori_uji;

-- 2. Coba hapus hanya kategori uji. ON DELETE RESTRICT menolak perintah ini.
DELETE FROM kategori WHERE id = @id_kategori_uji;

-- 3. Sesudah penolakan, kategori dan barang masih ada dan tetap berelasi.
SELECT k.id AS id_kategori, k.nama AS nama_kategori,
       b.id AS id_barang, b.nama AS nama_barang, b.kategori_id AS fk_kategori
FROM kategori AS k
INNER JOIN barang AS b ON b.kategori_id = k.id
WHERE k.id = @id_kategori_uji AND b.id = @id_barang_uji;

-- 4. Batalkan penambahan data demo. Kedua hitungan seharusnya kembali 0.
ROLLBACK;
SELECT (SELECT COUNT(*) FROM kategori WHERE id = @id_kategori_uji) AS sisa_kategori_uji,
       (SELECT COUNT(*) FROM barang WHERE id = @id_barang_uji) AS sisa_barang_uji;
