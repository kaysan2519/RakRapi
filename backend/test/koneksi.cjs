const { test } = require('node:test');
const assert = require('node:assert/strict');
const { opsiKoneksi } = require('../dist/config/koneksi');
const { aturCors } = require('../dist/middleware/cors.middleware');

function denganEnv(nilai, periksa) {
  const nama = ['DB_HOST', 'DB_PORT', 'DB_USER', 'DB_PASSWORD', 'DB_NAME', 'DB_SSL', 'DB_SSL_CA_BASE64', 'CORS_ORIGIN'];
  const sebelum = Object.fromEntries(nama.map(key => [key, process.env[key]]));
  try {
    for (const key of nama) delete process.env[key];
    Object.assign(process.env, nilai);
    periksa();
  } finally {
    for (const key of nama) {
      delete process.env[key];
      if (sebelum[key] !== undefined) process.env[key] = sebelum[key];
    }
  }
}

const caDummyBase64 = Buffer.from('-----BEGIN CERTIFICATE-----\nDUMMY\n-----END CERTIFICATE-----\n').toString('base64');

test('Laragon lokal memakai localhost, port 3306, tanpa SSL', () => {
  denganEnv({ DB_USER: 'root', DB_PASSWORD: '' }, () => {
    const opsi = opsiKoneksi();
    assert.equal(opsi.host, 'localhost');
    assert.equal(opsi.port, 3306);
    assert.equal(opsi.database, 'rakrapi');
    assert.equal(opsi.user, 'root');
    assert.equal(opsi.connectTimeout, 3000);
    assert.equal(opsi.ssl, undefined);
    assert.equal(opsiKoneksi('database_uji').database, 'database_uji');
  });
});

test('Aiven wajib DB_SSL=true dan DB_SSL_CA_BASE64 yang valid', () => {
  denganEnv({ DB_HOST: 'uji.aivencloud.com', DB_SSL: 'false' }, () => {
    assert.throws(() => opsiKoneksi(), /DB_SSL=true/);
  });
  denganEnv({ DB_HOST: 'uji.aivencloud.com', DB_SSL: 'true' }, () => {
    assert.throws(() => opsiKoneksi(), /DB_SSL_CA_BASE64/);
  });
  denganEnv({ DB_HOST: 'uji.aivencloud.com', DB_SSL: 'true', DB_SSL_CA_BASE64: Buffer.from('bukan-ca').toString('base64') }, () => {
    assert.throws(() => opsiKoneksi(), /sertifikat CA/);
  });
  for (const port of ['0', '65536', 'abc', '3.5']) {
    denganEnv({ DB_PORT: port }, () => assert.throws(() => opsiKoneksi(), /DB_PORT/));
  }
});

test('Opsi Aiven memverifikasi sertifikat CA dan identitas host', () => {
  denganEnv({
    DB_HOST: 'uji.aivencloud.com',
    DB_PORT: '17374',
    DB_USER: 'rakrapi_app',
    DB_PASSWORD: 'sandi',
    DB_NAME: 'rakrapi',
    DB_SSL: 'true',
    DB_SSL_CA_BASE64: caDummyBase64,
  }, () => {
    const opsi = opsiKoneksi();
    assert.equal(opsi.host, 'uji.aivencloud.com');
    assert.equal(opsi.port, 17374);
    assert.equal(opsi.user, 'rakrapi_app');
    assert.equal(opsi.ssl.rejectUnauthorized, true);
    assert.equal(opsi.ssl.verifyIdentity, true);
    assert.ok(opsi.ssl.ca.toString('utf8').includes('BEGIN CERTIFICATE'));
    assert.equal(opsi.connectTimeout, 15000);
  });
});

test('CORS mendukung wildcard * saat development dan allowlist domain saat production', () => {
  function jalankan(method, origin) {
    const headers = {};
    let status = null, selesai = false, lanjut = false;
    const req = { method, get: nama => (nama.toLowerCase() === 'origin' ? origin : undefined) };
    const res = {
      vary: k => { headers.vary = k; },
      set: (k, v) => { headers[k.toLowerCase()] = v; },
      status: kode => { status = kode; return res; },
      end: () => { selesai = true; },
    };
    aturCors(req, res, () => { lanjut = true; });
    return { headers, status, selesai, lanjut };
  }

  denganEnv({ CORS_ORIGIN: '*' }, () => {
    const preflight = jalankan('OPTIONS', 'http://localhost:8080');
    assert.equal(preflight.status, 204);
    assert.equal(preflight.headers['access-control-allow-origin'], '*');
    const getDev = jalankan('GET', 'http://localhost:8080');
    assert.equal(getDev.lanjut, true);
    assert.equal(getDev.headers['access-control-allow-origin'], '*');
  });

  denganEnv({ CORS_ORIGIN: 'https://rakrapi.vercel.app/' }, () => {
    const preflightSah = jalankan('OPTIONS', 'https://rakrapi.vercel.app');
    assert.equal(preflightSah.status, 204);
    assert.equal(preflightSah.headers['access-control-allow-origin'], 'https://rakrapi.vercel.app');
    assert.equal(preflightSah.headers.vary, 'Origin');

    const preflightAsing = jalankan('OPTIONS', 'https://asing.example');
    assert.equal(preflightAsing.status, 403);
    assert.equal(preflightAsing.headers['access-control-allow-origin'], undefined);

    const tanpaOrigin = jalankan('GET', undefined);
    assert.equal(tanpaOrigin.lanjut, true);
    assert.equal(tanpaOrigin.headers['access-control-allow-origin'], undefined);
  });
});
