-- RakRapi — Migrasi non-destruktif sistem pemberhentian pegawai
-- Menambahkan status akun, alasan pemberhentian, dan tanggal pemberhentian pada tabel users.
-- Seluruh akun yang sudah ada otomatis berstatus 'aktif' tanpa menghapus riwayat atau relasi.

ALTER TABLE users
    ADD COLUMN status ENUM('aktif', 'diberhentikan') NOT NULL DEFAULT 'aktif' AFTER role,
    ADD COLUMN alasan_pemberhentian VARCHAR(500) NULL DEFAULT NULL AFTER status,
    ADD COLUMN diberhentikan_pada DATETIME NULL DEFAULT NULL AFTER alasan_pemberhentian;
