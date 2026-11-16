-- Jalankan sebagai administrator pada database yang dipilih.
-- Akun API khusus cukup mendapat EXECUTE pada prosedur ini.
DELIMITER //
CREATE PROCEDURE tambah_pegawai(
    IN nama_baru VARCHAR(100), IN email_baru VARCHAR(255), IN hash_baru VARCHAR(255)
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    INSERT INTO users (nama, email, password_hash, role)
    VALUES (nama_baru, email_baru, hash_baru, 'pegawai');
    SELECT LAST_INSERT_ID() AS id;
END//
DELIMITER ;
