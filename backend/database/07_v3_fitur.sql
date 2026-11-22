-- RakRapi V3 — Migrasi non-destruktif fitur Prototype V3
-- Aman dijalankan pada MySQL 8.0 (Laragon) maupun MySQL 8.4 (Aiven).
-- Mempertahankan seluruh 6 tabel inti (users, kategori, barang, lowongan, pesanan, detail_pesanan),
-- Primary Key, Foreign Key, prosedur tambah_pegawai, dan seluruh data asli.

-- 1. Perluasan tabel barang: deskripsi + satuan lebih lengkap (tanpa mengubah data lama)
ALTER TABLE barang
    ADD COLUMN deskripsi VARCHAR(500) NOT NULL DEFAULT '' AFTER satuan,
    DROP CHECK chk_barang_satuan,
    DROP CHECK chk_barang_botol_bulat,
    ADD CONSTRAINT chk_barang_satuan CHECK (
        satuan IN ('botol', 'kg', 'pcs', 'bungkus', 'pack', 'sisir', 'kotak', 'lembar', 'sachet')
    ),
    ADD CONSTRAINT chk_barang_botol_bulat CHECK (
        satuan = 'kg' OR stok = FLOOR(stok)
    );

-- 2. Perluasan tabel pesanan: status lengkap + metode & status pembayaran terpisah
ALTER TABLE pesanan
    MODIFY COLUMN status ENUM('Menunggu konfirmasi', 'Dikonfirmasi', 'Siap diambil', 'Selesai')
        NOT NULL DEFAULT 'Menunggu konfirmasi',
    ADD COLUMN metode_pembayaran ENUM('Bayar di kasir', 'Transfer bank')
        NOT NULL DEFAULT 'Bayar di kasir' AFTER status,
    ADD COLUMN status_pembayaran ENUM('Belum dibayar', 'Sudah dibayar')
        NOT NULL DEFAULT 'Belum dibayar' AFTER metode_pembayaran;

-- 3. Perluasan tabel lowongan: detail, persyaratan, lokasi, foto opsional, pin prioritas
ALTER TABLE lowongan
    ADD COLUMN deskripsi VARCHAR(1000) NOT NULL DEFAULT '' AFTER judul,
    ADD COLUMN persyaratan VARCHAR(1000) NOT NULL DEFAULT '' AFTER deskripsi,
    ADD COLUMN lokasi VARCHAR(150) NOT NULL DEFAULT 'Toko RakRapi' AFTER persyaratan,
    ADD COLUMN info_tambahan VARCHAR(150) NOT NULL DEFAULT '' AFTER lokasi,
    ADD COLUMN foto_key VARCHAR(255) NULL DEFAULT NULL AFTER info_tambahan,
    ADD COLUMN is_pinned BOOLEAN NOT NULL DEFAULT FALSE AFTER aktif,
    ADD COLUMN dibuat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER is_pinned;

-- 4. Tabel lamaran kerja (mencegah lamaran ganda per warga & lowongan)
CREATE TABLE IF NOT EXISTS lamaran (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    lowongan_id INT UNSIGNED NOT NULL,
    warga_id INT UNSIGNED NOT NULL,
    nama_pelamar VARCHAR(100) NOT NULL,
    keterangan VARCHAR(1000) NOT NULL,
    status ENUM('Menunggu verifikasi', 'Disetujui', 'Ditolak') NOT NULL DEFAULT 'Menunggu verifikasi',
    dibuat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY satu_lamaran_per_lowongan (lowongan_id, warga_id),
    CONSTRAINT fk_lamaran_lowongan FOREIGN KEY (lowongan_id)
        REFERENCES lowongan (id) ON DELETE CASCADE,
    CONSTRAINT fk_lamaran_warga FOREIGN KEY (warga_id)
        REFERENCES users (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. Tabel program bantuan sosial (bansos)
CREATE TABLE IF NOT EXISTS program_bansos (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nama VARCHAR(150) NOT NULL,
    deskripsi VARCHAR(1000) NOT NULL DEFAULT '',
    jenis_bantuan VARCHAR(150) NOT NULL DEFAULT '',
    persyaratan VARCHAR(1000) NOT NULL DEFAULT '',
    kuota INT UNSIGNED NOT NULL DEFAULT 1,
    foto_key VARCHAR(255) NULL DEFAULT NULL,
    aktif BOOLEAN NOT NULL DEFAULT TRUE,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    dibuat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_bansos_nama CHECK (CHAR_LENGTH(TRIM(nama)) > 0),
    CONSTRAINT chk_bansos_kuota CHECK (kuota >= 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. Tabel pengajuan bantuan sosial (tanpa NIK/data sensitif, mencegah pengajuan ganda)
CREATE TABLE IF NOT EXISTS pengajuan_bansos (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    program_id INT UNSIGNED NOT NULL,
    warga_id INT UNSIGNED NOT NULL,
    nama_pemohon VARCHAR(100) NOT NULL,
    keterangan VARCHAR(1000) NOT NULL,
    status ENUM('Menunggu verifikasi', 'Disetujui', 'Ditolak') NOT NULL DEFAULT 'Menunggu verifikasi',
    dibuat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY satu_pengajuan_per_program (program_id, warga_id),
    CONSTRAINT fk_pengajuan_program FOREIGN KEY (program_id)
        REFERENCES program_bansos (id) ON DELETE CASCADE,
    CONSTRAINT fk_pengajuan_warga FOREIGN KEY (warga_id)
        REFERENCES users (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. Tabel pengumuman & informasi diskon
CREATE TABLE IF NOT EXISTS pengumuman (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    judul VARCHAR(150) NOT NULL,
    deskripsi VARCHAR(1000) NOT NULL DEFAULT '',
    jenis ENUM('Pengumuman', 'Diskon', 'Informasi toko') NOT NULL DEFAULT 'Pengumuman',
    info_tambahan VARCHAR(150) NOT NULL DEFAULT '',
    foto_key VARCHAR(255) NULL DEFAULT NULL,
    aktif BOOLEAN NOT NULL DEFAULT TRUE,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    dibuat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_pengumuman_judul CHECK (CHAR_LENGTH(TRIM(judul)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 8. Tabel informasi toko & rekening toko opsional (1 baris dengan id = 1)
CREATE TABLE IF NOT EXISTS info_toko (
    id TINYINT UNSIGNED PRIMARY KEY,
    nama_toko VARCHAR(150) NOT NULL DEFAULT 'Toko Sembako RakRapi (Demo)',
    alamat VARCHAR(300) NOT NULL DEFAULT '',
    jam_operasional VARCHAR(150) NOT NULL DEFAULT 'Buka setiap hari · 07.00–21.00 (Demo)',
    kontak VARCHAR(100) NOT NULL DEFAULT '',
    info_pengambilan VARCHAR(300) NOT NULL DEFAULT 'Ambil di kasir toko setelah status pesanan Siap diambil.',
    nama_bank VARCHAR(100) NULL DEFAULT NULL,
    nomor_rekening VARCHAR(50) NULL DEFAULT NULL,
    nama_pemilik_rekening VARCHAR(150) NULL DEFAULT NULL,
    diperbarui DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_info_toko_tunggal CHECK (id = 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
