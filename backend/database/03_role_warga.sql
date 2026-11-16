-- Jalankan setelah 01_skema.sql pada database yang dipilih.
-- Default baru hanya berlaku pada INSERT berikutnya.
ALTER TABLE users
    DROP CHECK chk_users_role,
    ALTER COLUMN role SET DEFAULT 'warga',
    ADD CONSTRAINT chk_users_role_akun CHECK (role IN ('pemilik', 'pegawai', 'warga'));
