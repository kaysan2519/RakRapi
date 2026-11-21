// Jalankan dari backend: node --test test/foto.cjs
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { periksaFoto, periksaDimensiFoto } = require('../dist/validations/foto.validation');
const {
  aturKlienCloudinaryUntukUji,
  bacaFoto,
  hapusJikaLepas,
  memakaiCloudinary,
  siapkanFoto,
  tulisFoto,
} = require('../dist/services/foto.service');
const { KesalahanKatalog } = require('../dist/middleware/error.middleware');

function buatGambarContoh() {
  // Gambar valid kecil dibuat di RAM agar tidak perlu file contoh di repo.
  const skrip = `
    Add-Type -AssemblyName System.Drawing
    $bitmap=[Drawing.Bitmap]::new(12,8)
    $bitmap.SetPixel(4,4,[Drawing.Color]::ForestGreen)
    foreach ($format in @([Drawing.Imaging.ImageFormat]::Png,[Drawing.Imaging.ImageFormat]::Jpeg)) {
      $stream=New-Object IO.MemoryStream
      $bitmap.Save($stream,$format)
      [Convert]::ToBase64String($stream.ToArray())
      $stream.Dispose()
    }
    $bitmap.Dispose()`;
  const [png, jpg] = execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', skrip], {
    windowsHide: true,
    encoding: 'utf8',
  }).trim().split(/\r?\n/).map(b => Buffer.from(b, 'base64'));
  return { png, jpg };
}

function fileMulter(buffer, mimetype) {
  return { buffer, mimetype, size: buffer.length };
}

function pngDenganHeaderValidIsiRusak(pngAsli) {
  const salinan = Buffer.from(pngAsli);
  let posisi = 8;
  while (posisi + 12 <= salinan.length) {
    const panjang = salinan.readUInt32BE(posisi);
    const tipe = salinan.toString('ascii', posisi + 4, posisi + 8);
    if (tipe === 'IDAT' && panjang > 4) {
      // Rusak byte isi IDAT tanpa merusak struktur panjang chunk atau header IHDR.
      salinan[posisi + 8] ^= 0xff;
      salinan[posisi + 9] ^= 0xff;
      salinan[posisi + 10] ^= 0xff;
      return salinan;
    }
    posisi += 12 + panjang;
  }
  throw new Error('Chunk IDAT tidak ditemukan.');
}

function pngDimensiBesar(pngAsli, lebar, tinggi) {
  const salinan = Buffer.from(pngAsli);
  salinan.writeUInt32BE(lebar, 16);
  salinan.writeUInt32BE(tinggi, 20);
  return salinan;
}

function jpegDimensiBesar(lebar, tinggi) {
  // JPEG minimal dengan segmen SOF0 (dimensi besar) + SOS + EOI.
  const sof0 = Buffer.from([
    0xff, 0xc0, 0x00, 0x0b, 0x08,
    (tinggi >> 8) & 0xff, tinggi & 0xff,
    (lebar >> 8) & 0xff, lebar & 0xff,
    0x01, 0x01, 0x11, 0x00,
  ]);
  const sos = Buffer.from([0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3f, 0x00, 0x00]);
  return Buffer.concat([Buffer.from([0xff, 0xd8]), sof0, sos, Buffer.from([0xff, 0xd9])]);
}

function denganEnvFoto(nilai, kerja) {
  const kunci = ['FOTO_STORAGE', 'UPLOAD_DIR', 'CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET'];
  const sebelum = Object.fromEntries(kunci.map(k => [k, process.env[k]]));
  try {
    for (const k of kunci) delete process.env[k];
    Object.assign(process.env, nilai);
    return kerja();
  } finally {
    for (const k of kunci) {
      delete process.env[k];
      if (sebelum[k] !== undefined) process.env[k] = sebelum[k];
    }
  }
}

const { png, jpg } = buatGambarContoh();

test('Validasi foto menerima PNG dan JPEG valid pada Windows dan Linux+Cloudinary', async () => {
  assert.equal(await periksaFoto(fileMulter(png, 'image/png'), { platform: 'win32' }), 'png');
  assert.equal(await periksaFoto(fileMulter(jpg, 'image/jpeg'), { platform: 'win32' }), 'jpg');
  assert.equal(await periksaFoto(fileMulter(png, 'image/png'), { platform: 'linux', pakaiCloudinary: true }), 'png');
  assert.equal(await periksaFoto(fileMulter(jpg, 'image/jpeg'), { platform: 'linux', pakaiCloudinary: true }), 'jpg');
  assert.deepEqual(periksaDimensiFoto(png, 'png'), { lebar: 12, tinggi: 8 });
  assert.deepEqual(periksaDimensiFoto(jpg, 'jpg'), { lebar: 12, tinggi: 8 });
});

test('Validasi foto menolak MIME palsu, ukuran > 5 MiB, dimensi > 16 MP, dan gambar korup di tengah', async () => {
  // MIME palsu
  await assert.rejects(
    periksaFoto(fileMulter(png, 'image/jpeg'), { platform: 'linux', pakaiCloudinary: true }),
    err => err instanceof KesalahanKatalog && err.status === 415,
  );
  await assert.rejects(
    periksaFoto(fileMulter(jpg, 'image/png'), { platform: 'win32' }),
    err => err instanceof KesalahanKatalog && err.status === 415,
  );
  await assert.rejects(
    periksaFoto(fileMulter(Buffer.from('bukan gambar sama sekali ini teks biasa'), 'image/png'), { platform: 'linux', pakaiCloudinary: true }),
    err => err instanceof KesalahanKatalog && err.status === 415,
  );

  // Melebihi 5 MiB
  await assert.rejects(
    periksaFoto(fileMulter(Buffer.alloc(5 * 1024 * 1024 + 1), 'image/png'), { platform: 'linux', pakaiCloudinary: true }),
    err => err instanceof KesalahanKatalog && err.status === 413,
  );

  // Melebihi 16 megapiksel (5000 x 4000 = 20 MP) untuk PNG & JPEG pada Windows dan Linux
  const png20Mp = pngDimensiBesar(png, 5000, 4000);
  const jpg20Mp = jpegDimensiBesar(5000, 4000);
  for (const opsi of [{ platform: 'win32' }, { platform: 'linux', pakaiCloudinary: true }]) {
    await assert.rejects(
      periksaFoto(fileMulter(png20Mp, 'image/png'), opsi),
      err => err instanceof KesalahanKatalog && err.status === 415,
    );
    await assert.rejects(
      periksaFoto(fileMulter(jpg20Mp, 'image/jpeg'), opsi),
      err => err instanceof KesalahanKatalog && err.status === 415,
    );
  }

  // Gambar korup pada bagian tengah (magic bytes awal & akhir valid, chunk tengah rusak)
  const korupTengah = Buffer.concat([png.subarray(0, 8), Buffer.from('rusak-di-tengah-chunk'), png.subarray(-12)]);
  for (const opsi of [{ platform: 'win32' }, { platform: 'linux', pakaiCloudinary: true }]) {
    await assert.rejects(
      periksaFoto(fileMulter(korupTengah, 'image/png'), opsi),
      err => err instanceof KesalahanKatalog && err.status === 415,
    );
  }

  // Gambar header IHDR valid tetapi isi IDAT rusak: wajib ditolak 415 pada Windows dan Linux
  const headerValidIsiRusak = pngDenganHeaderValidIsiRusak(png);
  for (const opsi of [{ platform: 'win32' }, { platform: 'linux', pakaiCloudinary: true }]) {
    await assert.rejects(
      periksaFoto(fileMulter(headerValidIsiRusak, 'image/png'), opsi),
      err => err instanceof KesalahanKatalog && err.status === 415,
    );
  }

  // Linux tanpa Cloudinary tidak boleh diam-diam meloloskan gambar tanpa decode penuh
  await assert.rejects(
    periksaFoto(fileMulter(png, 'image/png'), { platform: 'linux', pakaiCloudinary: false }),
    err => err instanceof KesalahanKatalog && err.status === 503,
  );
});

test('Cloudinary: simpan/baca privat, tolak isi rusak 415, gangguan jaringan 503, dan pembersihan aman saat DB gagal', async () => {
  const penyimpanan = new Map();
  const dihapus = [];
  let modeKlien = 'normal';

  aturKlienCloudinaryUntukUji({
    async unggah(publicId, bytes) {
      if (modeKlien === 'rusak') {
        const err = new Error('Invalid image file');
        err.http_code = 400;
        throw err;
      }
      if (modeKlien === 'dimensi-berlebih') {
        penyimpanan.set(publicId, bytes);
        return { format: 'png', width: 5000, height: 4000 };
      }
      if (modeKlien === 'gangguan') {
        throw Object.assign(new Error('connect ECONNREFUSED'), { code: 'ECONNREFUSED' });
      }
      penyimpanan.set(publicId, bytes);
      return { format: bytes[0] === 137 ? 'png' : 'jpg', width: 12, height: 8 };
    },
    async unduh(publicId) {
      if (modeKlien === 'gangguan') {
        throw new Error('network error');
      }
      const data = penyimpanan.get(publicId);
      if (!data) {
        throw new KesalahanKatalog(404, 'Foto tidak ditemukan.');
      }
      return data;
    },
    async hapus(publicId) {
      dihapus.push(publicId);
      penyimpanan.delete(publicId);
    },
  });

  try {
    // 1. PNG & JPEG valid tersimpan dan terbaca kembali dengan byte identik
    const siapPng = await siapkanFoto(fileMulter(png, 'image/png'));
    await tulisFoto(siapPng);
    const terbacaPng = await bacaFoto(siapPng.key);
    assert.equal(terbacaPng.mime, 'image/png');
    assert.deepEqual(terbacaPng.bytes, png);

    const siapJpg = await siapkanFoto(fileMulter(jpg, 'image/jpeg'));
    await tulisFoto(siapJpg);
    const terbacaJpg = await bacaFoto(siapJpg.key);
    assert.equal(terbacaJpg.mime, 'image/jpeg');
    assert.deepEqual(terbacaJpg.bytes, jpg);

    // 2. Gambar header valid isi rusak ditolak Cloudinary (400 -> 415) tanpa menyimpan aset
    modeKlien = 'rusak';
    const kunciRusak = '11111111-1111-4111-8111-111111111111.png';
    await assert.rejects(
      tulisFoto({ key: kunciRusak, bytes: pngDenganHeaderValidIsiRusak(png) }),
      err => err instanceof KesalahanKatalog && err.status === 415,
    );

    // 3. Jika Cloudinary melaporkan dimensi > 16 MP, aset langsung dibersihkan dan ditolak 415
    modeKlien = 'dimensi-berlebih';
    const kunciBesar = '22222222-2222-4222-8222-222222222222.png';
    await assert.rejects(
      tulisFoto({ key: kunciBesar, bytes: png }),
      err => err instanceof KesalahanKatalog && err.status === 415,
    );
    assert.ok(dihapus.some(id => id.endsWith('22222222-2222-4222-8222-222222222222')));

    // 4. Gangguan koneksi Cloudinary menghasilkan 503
    modeKlien = 'gangguan';
    await assert.rejects(
      tulisFoto({ key: '33333333-3333-4333-8333-333333333333.png', bytes: png }),
      err => err instanceof KesalahanKatalog && err.status === 503,
    );
    await assert.rejects(
      bacaFoto(siapPng.key),
      err => err instanceof KesalahanKatalog && err.status === 503,
    );

    // 5. Kegagalan DB: aset baru yatim dihapus, foto asli yang masih dirujuk TIDAK dihapus
    modeKlien = 'normal';
    const dbSimulasi = (dirujuk) => ({
      select: () => ({
        from: () => ({
          where: () => ({
            limit: async () => (dirujuk ? [{ id: 2 }] : []),
          }),
        }),
      }),
    });

    const jumlahHapusSebelum = dihapus.length;
    await hapusJikaLepas(dbSimulasi(true), siapPng.key);
    assert.equal(dihapus.length, jumlahHapusSebelum, 'foto asli yang masih dirujuk tidak boleh dihapus');

    await hapusJikaLepas(dbSimulasi(false), siapJpg.key);
    assert.equal(dihapus.length, jumlahHapusSebelum + 1, 'aset yatim wajib dibersihkan');
    await assert.rejects(
      bacaFoto(siapJpg.key),
      err => err instanceof KesalahanKatalog && err.status === 404,
    );
    // Foto asli masih utuh dan terbaca
    assert.deepEqual((await bacaFoto(siapPng.key)).bytes, png);
  } finally {
    aturKlienCloudinaryUntukUji(undefined);
  }
});

test('Pemilihan mode penyimpanan foto: lokal default, UPLOAD_DIR paksa lokal, kredensial parsial ditolak', () => {
  assert.equal(denganEnvFoto({}, () => memakaiCloudinary()), false);
  assert.equal(
    denganEnvFoto(
      { UPLOAD_DIR: 'C:/tmp/uji', CLOUDINARY_CLOUD_NAME: 'a', CLOUDINARY_API_KEY: 'b', CLOUDINARY_API_SECRET: 'c' },
      () => memakaiCloudinary(),
    ),
    false,
  );
  assert.equal(
    denganEnvFoto(
      { CLOUDINARY_CLOUD_NAME: 'a', CLOUDINARY_API_KEY: 'b', CLOUDINARY_API_SECRET: 'c' },
      () => memakaiCloudinary(),
    ),
    true,
  );
  assert.throws(
    () => denganEnvFoto({ CLOUDINARY_CLOUD_NAME: 'a' }, () => memakaiCloudinary()),
    err => err instanceof KesalahanKatalog && err.status === 503,
  );
});
