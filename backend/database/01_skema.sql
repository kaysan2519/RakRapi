-- RakRapi | MySQL 8.0.30
-- Jalankan sekali setelah memeriksa database dan memastikan nama tabel tersedia.
-- Jika tabel sudah ada, bandingkan SHOW CREATE TABLE sebelum melanjutkan.
CREATE DATABASE IF NOT EXISTS rakrapi CHARACTER SET utf8mb4;
USE rakrapi;

-- Akun untuk dua peran. Password disimpan sebagai hash.
CREATE TABLE users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nama VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(10) NOT NULL DEFAULT 'pegawai',
    CONSTRAINT chk_users_role CHECK (role IN ('pemilik', 'pegawai'))
) ENGINE = InnoDB;

-- Satu kategori dapat dibuat sebelum memiliki barang.
CREATE TABLE kategori (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nama VARCHAR(100) NOT NULL UNIQUE,
    CONSTRAINT chk_kategori_nama CHECK (CHAR_LENGTH(TRIM(nama)) > 0)
) ENGINE = InnoDB;

-- Harga dalam rupiah per satuan. Stok kg boleh pecahan, stok botol harus bulat.
-- foto_key hanya menyimpan penanda foto. Lokasi penyimpanan dibahas di fase backend.
CREATE TABLE barang (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    kategori_id INT UNSIGNED NOT NULL,
    nama VARCHAR(150) NOT NULL,
    harga_rupiah INT UNSIGNED NOT NULL,
    stok DECIMAL(12,3) NOT NULL,
    satuan VARCHAR(20) NOT NULL,
    foto_key VARCHAR(255) NOT NULL,
    CONSTRAINT chk_barang_nama CHECK (CHAR_LENGTH(TRIM(nama)) > 0),
    CONSTRAINT chk_barang_stok CHECK (stok >= 0),
    CONSTRAINT chk_barang_satuan CHECK (satuan IN ('botol', 'kg')),
    CONSTRAINT chk_barang_botol_bulat CHECK (satuan <> 'botol' OR stok = FLOOR(stok)),
    CONSTRAINT fk_barang_kategori FOREIGN KEY (kategori_id)
        REFERENCES kategori (id) ON DELETE RESTRICT
) ENGINE = InnoDB;
