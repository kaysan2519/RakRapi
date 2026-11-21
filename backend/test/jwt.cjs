const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');

// Dipanggil runner akun: seluruh perubahan pengguna hanya di database sementara.
async function ujiJwt({ api, pemilik, pegawai, warga, emailPemilik, password, kunciJwtUji, sql }) {
  let jumlah = 0;
  async function http(method, route, status, token, body) {
    const headers = { 'Content-Type': 'application/json' };
    if (token !== undefined) headers.Authorization = 'Bearer ' + token;
    const res = await fetch(api + route, { method, headers, body: JSON.stringify(body) });
    assert.equal(res.status, status, method + ' ' + route);
    const data = await res.json();
    assert.ok(!/password|password_hash|passwordHash/.test(JSON.stringify(data)), 'respons tanpa sandi/hash');
    jumlah++;
    return data;
  }

  for (const [role, token] of Object.entries({ pemilik, pegawai, warga })) {
    const claims = jwt.verify(token, kunciJwtUji, { algorithms: ['HS256'], issuer: 'rakrapi' });
    assert.deepEqual(Object.keys(claims).sort(), ['exp', 'iat', 'iss', 'sub']);
    assert.equal(claims.exp - claims.iat, 3600);
    assert.equal((await http('GET', '/auth/me', 200, token)).user.role, role);
    await http('GET', '/barang', 200, token);
    await http('GET', '/auth/pemilik', role === 'pemilik' ? 200 : 403, token);
  }
  await http('POST', '/auth/login', 200, undefined, { email: emailPemilik, password });
  await http('POST', '/auth/login', 401, undefined, { email: emailPemilik, password: password + 'salah' });
  await http('POST', '/auth/login', 401, undefined, { email: 'tidak-ada@rakrapi.test', password });

  const id = jwt.verify(warga, kunciJwtUji).sub;
  const opsi = { subject: id, issuer: 'rakrapi', algorithm: 'HS256', expiresIn: '1h' };
  const rusak = warga.split('.');
  rusak[2] = (rusak[2][0] === 'A' ? 'B' : 'A') + rusak[2].slice(1);
  const tidakSah = [
    undefined, '', 'bukan-jwt', rusak.join('.'),
    jwt.sign({}, kunciJwtUji, { ...opsi, expiresIn: -1 }),
    jwt.sign({}, 'kunci-uji-lain-yang-tidak-dipakai-server', opsi),
    jwt.sign({}, kunciJwtUji, { ...opsi, algorithm: 'HS384' }),
    jwt.sign({}, null, { ...opsi, algorithm: 'none' }),
    jwt.sign({}, kunciJwtUji, { ...opsi, issuer: 'bukan-rakrapi' }),
    jwt.sign({}, kunciJwtUji, { subject: id, issuer: 'rakrapi', algorithm: 'HS256' }),
    jwt.sign({}, kunciJwtUji, { ...opsi, subject: '0' }),
    jwt.sign({}, kunciJwtUji, { ...opsi, subject: '4294967295' }),
  ];
  for (const token of tidakSah) {
    for (const route of ['/auth/me', '/barang', '/barang/2/foto', '/kategori', '/lowongan', '/pesanan']) {
      await http('GET', route, 401, token);
    }
  }

  // Klaim role tambahan tidak memberi hak: middleware membaca role dari MySQL.
  const rolePalsu = jwt.sign({ role: 'pemilik' }, kunciJwtUji, opsi);
  await http('GET', '/auth/pemilik', 403, rolePalsu);
  assert.equal((await http('GET', '/auth/me', 200, rolePalsu)).user.role, 'warga');
  const idPemilik = Number(jwt.verify(pemilik, kunciJwtUji).sub);
  assert.ok(Number.isSafeInteger(idPemilik));
  sql("UPDATE users SET role='pegawai' WHERE id=" + idPemilik);
  try {
    assert.equal((await http('GET', '/auth/me', 200, pemilik)).user.role, 'pegawai');
    await http('GET', '/auth/pemilik', 403, pemilik);
  } finally {
    sql("UPDATE users SET role='pemilik' WHERE id=" + idPemilik);
  }
  await http('GET', '/auth/pemilik', 200, pemilik);
  await http('GET', '/health', 200);
  console.log(`JWT: ${jumlah} pemeriksaan HTTP lulus; login 200/401, token tidak sah 401, role 200/403, HS256/3600 detik, role terbaru dari MySQL.`);
}

module.exports = { ujiJwt };
