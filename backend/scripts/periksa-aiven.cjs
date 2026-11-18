// Baca saja: tidak membuat database, mengubah tabel, atau mengisi katalog.
// Jalankan dari backend setelah build, dengan file env privat Aiven.
const mysql = require('mysql2/promise');
const { drizzle } = require('drizzle-orm/mysql2');
const { sql } = require('drizzle-orm');
const { opsiKoneksi } = require('../dist/config/koneksi');

async function periksa() {
  if (process.env.DB_MODE !== 'aiven') {
    throw Error('Gunakan konfigurasi DB_MODE=aiven.');
  }
  const opsi = opsiKoneksi(process.env.DB_USER, process.env.DB_PASSWORD);
  // Tetap bisa memeriksa layanan yang belum memiliki database rakrapi.
  delete opsi.database;
  const koneksi = await mysql.createConnection(opsi);
  try {
    const saluran = koneksi.connection.stream;
    if (!saluran.encrypted || !saluran.authorized) {
      throw Error('Koneksi TLS belum terverifikasi.');
    }
    const [[server]] = await koneksi.query('SELECT @@hostname AS server_mysql, @@port AS port_mysql');
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
      tabel_terlihat_kosong: tabel.length === 0,
    }, null, 2));
    if (tabel.length) {
      console.log('Database sudah berisi tabel. Periksa dan laporkan isinya sebelum migration.');
    } else {
      console.log('Tidak ada tabel yang terlihat oleh akun ini. Pastikan pemeriksaan memakai akun administrator sebelum migration.');
    }
  } finally {
    await koneksi.end();
  }
}

periksa().catch((error) => {
  // Pesan driver bisa mengandung akun/host; jangan cetak objek error atau URI koneksi.
  const kode = /^[A-Z0-9_]+$/.test(error.code ?? '') ? error.code : 'KONFIGURASI_ATAU_KONEKSI';
  console.error('Pemeriksaan Aiven gagal: ' + kode + '. Periksa env privat, CA, dan jaringan.');
  process.exitCode = 1;
});
