// Baca saja: tidak membuat database, mengubah tabel, atau mengisi katalog.
// Jalankan dari backend setelah build: npm run cek:aiven
const mysql = require('mysql2/promise');
const { drizzle } = require('drizzle-orm/mysql2');
const { sql } = require('drizzle-orm');
const { opsiKoneksi } = require('../dist/config/koneksi');

async function periksa() {
  if (process.env.DB_SSL !== 'true') {
    throw Error('Gunakan konfigurasi Aiven dengan DB_SSL=true dan DB_SSL_CA_BASE64.');
  }
  const opsi = opsiKoneksi();
  delete opsi.database;
  const koneksi = await mysql.createConnection(opsi);
  try {
    const saluran = koneksi.connection.stream;
    if (!saluran.encrypted || !saluran.authorized) {
      throw Error('Koneksi TLS belum terverifikasi.');
    }
    const [[server]] = await koneksi.query('SELECT @@hostname AS server_mysql, @@port AS port_mysql, CURRENT_USER() AS akun_aktif');
    const [tabel] = await koneksi.query(`
      SELECT TABLE_SCHEMA AS nama_database, TABLE_NAME AS nama_tabel
      FROM information_schema.TABLES
      WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
      ORDER BY TABLE_SCHEMA, TABLE_NAME
    `);
    const [database] = await koneksi.query("SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = 'rakrapi'");
    let namaDatabase = null;
    if (database.length) {
      await koneksi.query('USE rakrapi');
      const [baris] = await drizzle(koneksi).execute(sql`SELECT DATABASE() AS nama_database`);
      namaDatabase = baris[0].nama_database;
    }

    console.log(JSON.stringify({
      host_tujuan: opsi.host,
      port_tujuan: opsi.port,
      tls_terverifikasi: true,
      protokol_tls: saluran.getProtocol(),
      sidik_sertifikat: saluran.getPeerCertificate().fingerprint256,
      ...server,
      nama_database_drizzle: namaDatabase,
      tabel,
    }, null, 2));
  } finally {
    await koneksi.end();
  }
}

periksa().catch((error) => {
  const kode = /^[A-Z0-9_]+$/.test(error.code ?? '') ? error.code : 'KONFIGURASI_ATAU_KONEKSI';
  console.error('Pemeriksaan Aiven gagal: ' + kode + '. Periksa .env, CA base64, dan jaringan.');
  process.exitCode = 1;
});
