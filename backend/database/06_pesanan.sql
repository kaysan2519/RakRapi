CREATE TABLE pesanan (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    warga_id INT UNSIGNED NOT NULL,
    nama_pemesan VARCHAR(100) NOT NULL,
    kunci_kirim CHAR(32) NOT NULL,
    status ENUM('Menunggu konfirmasi', 'Dikonfirmasi') NOT NULL DEFAULT 'Menunggu konfirmasi',
    total_rupiah DECIMAL(32,0) NOT NULL,
    dibuat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY satu_pengiriman (warga_id, kunci_kirim),
    FOREIGN KEY (warga_id) REFERENCES users(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE detail_pesanan (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pesanan_id INT UNSIGNED NOT NULL,
    barang_id INT UNSIGNED NULL,
    nama_barang VARCHAR(150) NOT NULL,
    satuan VARCHAR(20) NOT NULL,
    jumlah DECIMAL(12,3) NOT NULL CHECK (jumlah > 0),
    harga_rupiah INT UNSIGNED NOT NULL,
    UNIQUE KEY satu_baris_barang (pesanan_id, barang_id),
    FOREIGN KEY (pesanan_id) REFERENCES pesanan(id) ON DELETE RESTRICT,
    FOREIGN KEY (barang_id) REFERENCES barang(id) ON DELETE SET NULL
) ENGINE=InnoDB;
