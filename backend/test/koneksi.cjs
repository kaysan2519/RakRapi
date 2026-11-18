const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { opsiKoneksi } = require('../dist/config/koneksi');

// Hanya memeriksa konfigurasi. Tidak menghubungi atau menulis ke database.
function denganEnv(nilai, periksa) {
  const nama = ['DB_MODE', 'DB_HOST', 'DB_PORT', 'DB_NAME', 'DB_SSL_CA'];
  const sebelum = Object.fromEntries(nama.map((key) => [key, process.env[key]]));
  try {
    for (const key of nama) {
      delete process.env[key];
    }
    Object.assign(process.env, nilai);
    periksa();
  } finally {
    for (const key of nama) {
      delete process.env[key];
      if (sebelum[key] !== undefined) {
        process.env[key] = sebelum[key];
      }
    }
  }
}

test('Laragon tetap localhost, port 3306, tanpa TLS tambahan', () => {
  denganEnv({}, () => {
    const opsi = opsiKoneksi('akun', 'sandi');
    assert.equal(opsi.host, '127.0.0.1');
    assert.equal(opsi.port, 3306);
    assert.equal(opsi.database, 'rakrapi');
    assert.equal(opsi.connectTimeout, 3000);
    assert.equal(opsi.ssl, undefined);
    assert.equal(opsiKoneksi('akun', 'sandi', 'database_uji').database, 'database_uji');
  });
});

test('Aiven menolak host lokal, CA kosong, kredensial kosong, dan CA tidak terbaca', () => {
  denganEnv({ DB_MODE: 'aiven' }, () => assert.throws(() => opsiKoneksi('akun', 'sandi'), /DB_HOST/));
  const cloud = { DB_MODE: 'aiven', DB_HOST: 'uji.aivencloud.com' };
  denganEnv(cloud, () => assert.throws(() => opsiKoneksi('akun', 'sandi'), /DB_SSL_CA/));
  denganEnv({ ...cloud, DB_SSL_CA: 'tidak-ada.pem' }, () => {
    assert.throws(() => opsiKoneksi('akun', undefined), /konfigurasi privat/);
    assert.throws(() => opsiKoneksi('akun', 'sandi'), /tidak bisa dibaca/);
  });
});

test('Host Aiven tidak bisa memakai mode Laragon', () => {
  denganEnv({ DB_HOST: 'uji.aivencloud.com' }, () => assert.throws(() => opsiKoneksi('akun', 'sandi'), /DB_MODE=aiven/));
});

test('Mode dan nomor port yang keliru ditolak', () => {
  denganEnv({ DB_MODE: 'salah' }, () => assert.throws(() => opsiKoneksi('akun', 'sandi'), /DB_MODE/));
  for (const port of ['0', '65536', 'abc', '3.5']) {
    denganEnv({ DB_PORT: port }, () => assert.throws(() => opsiKoneksi('akun', 'sandi'), /DB_PORT/));
  }
});

test('Opsi Aiven selalu memverifikasi CA dan identitas host untuk setiap akun', () => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'rakrapi-konfigurasi-'));
  const file = path.join(folder, 'ca.pem');
  try {
    // Fixture hanya untuk membaca opsi; bukan bukti handshake TLS dengan Aiven.
    fs.writeFileSync(file, 'fixture CA');
    denganEnv({ DB_MODE: 'aiven', DB_HOST: 'uji.aivencloud.com', DB_PORT: '17374', DB_SSL_CA: file }, () => {
      for (const akun of ['health', 'auth', 'pegawai', 'katalog']) {
        const opsi = opsiKoneksi(akun, 'sandi');
        assert.equal(opsi.port, 17374);
        assert.equal(opsi.user, akun);
        assert.equal(opsi.ssl.ca.toString(), 'fixture CA');
        assert.equal(opsi.ssl.rejectUnauthorized, true);
        assert.equal(opsi.ssl.verifyIdentity, true);
        assert.equal(opsi.connectTimeout, 15000);
      }
    });
  } finally {
    fs.unlinkSync(file);
    fs.rmdirSync(folder);
  }
});
