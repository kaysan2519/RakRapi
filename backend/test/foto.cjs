// Jalankan dari backend: node --test test/foto.cjs
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const { periksaFoto } = require('../dist/validations/foto.validation');
const {
  aturKlienCloudinaryUntukUji,
  bacaFoto,
  hapusJikaLepas,
  memakaiCloudinary,
  siapkanFoto,
  tulisFoto,
} = require('../dist/services/foto.service');
const { KesalahanKatalog } = require('../dist/middleware/error.middleware');

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
      salinan[posisi + 8] ^= 0xff;
      salinan[posisi + 9] ^= 0xff;
      salinan[posisi + 10] ^= 0xff;
      return salinan;
    }
    posisi += 12 + panjang;
  }
  throw new Error('Chunk IDAT tidak ditemukan.');
}

function jpegHeaderValidScanRusak(jpgAsli, kosong = false) {
  const salinan = Buffer.from(jpgAsli);
  let pos = 2;
  while (pos < salinan.length - 2) {
    if (salinan[pos] !== 0xff) break;
    while (pos < salinan.length && salinan[pos] === 0xff) pos++;
    const marker = salinan[pos++];
    if (marker === 0xd9) break;
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
    const len = salinan.readUInt16BE(pos);
    if (marker === 0xda) {
      const prefix = salinan.subarray(0, pos + len);
      if (kosong) {
        return Buffer.concat([prefix, Buffer.from([0xff, 0xd9])]);
      }
      const sampah = Buffer.from('deadbeef00ff1234567890abcdef00ff99887766', 'hex');
      return Buffer.concat([prefix, sampah, Buffer.from([0xff, 0xd9])]);
    }
    pos += len;
  }
  throw new Error('SOS tidak ditemukan.');
}

function pngDimensiBesar(pngAsli, lebar, tinggi) {
  const salinan = Buffer.from(pngAsli);
  salinan.writeUInt32BE(lebar, 16);
  salinan.writeUInt32BE(tinggi, 20);
  return salinan;
}

function jpegDimensiBesar(lebar, tinggi) {
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

async function buatGambarValid() {
  const png = await sharp({ create: { width: 32, height: 24, channels: 3, background: { r: 18, g: 43, b: 34 } } })
    .png()
    .toBuffer();
  const jpg = await sharp({ create: { width: 32, height: 24, channels: 3, background: { r: 18, g: 43, b: 34 } } })
    .jpeg({ quality: 90 })
    .toBuffer();
  return { png, jpg };
}

test('Validasi Sharp menerima PNG/JPEG valid tanpa mengubah byte asli', async () => {
  const { png, jpg } = await buatGambarValid();
  const salinanPng = Buffer.from(png);
  const salinanJpg = Buffer.from(jpg);

  assert.equal(await periksaFoto(fileMulter(png, 'image/png')), 'png');
  assert.equal(await periksaFoto(fileMulter(jpg, 'image/jpeg')), 'jpg');
  // Pastikan byte asli tidak dikompresi atau diubah
  assert.equal(Buffer.compare(png, salinanPng), 0);
  assert.equal(Buffer.compare(jpg, salinanJpg), 0);

  // Foto produk asli ID 2 (baca saja) jika tersedia di mesin lokal
  const lokasiFotoAsli = path.join(__dirname, '../private/uploads/db-rakrapi/431a9e84-3c42-438a-b876-a2f8816c61dd.png');
  if (fs.existsSync(lokasiFotoAsli)) {
    const asli = fs.readFileSync(lokasiFotoAsli);
    assert.equal(await periksaFoto(fileMulter(asli, 'image/png')), 'png');
  }
});

test('Validasi Sharp menolak PNG korup, JPEG scan korup, JPEG scan kosong, MIME palsu, >5 MiB, dan >16 MP', async () => {
  const { png, jpg } = await buatGambarValid();

  // MIME palsu
  await assert.rejects(
    periksaFoto(fileMulter(png, 'image/jpeg')),
    err => err instanceof KesalahanKatalog && err.status === 415,
  );
  await assert.rejects(
    periksaFoto(fileMulter(jpg, 'image/png')),
    err => err instanceof KesalahanKatalog && err.status === 415,
  );
  await assert.rejects(
    periksaFoto(fileMulter(Buffer.from('bukan gambar sama sekali ini teks biasa'), 'image/png')),
    err => err instanceof KesalahanKatalog && err.status === 415,
  );

  // Ukuran > 5 MiB -> 413
  await assert.rejects(
    periksaFoto(fileMulter(Buffer.alloc(5 * 1024 * 1024 + 1), 'image/png')),
    err => err instanceof KesalahanKatalog && err.status === 413,
  );

  // Dimensi > 16 MP (5000x4000 = 20 MP) -> 415
  await assert.rejects(
    periksaFoto(fileMulter(pngDimensiBesar(png, 5000, 4000), 'image/png')),
    err => err instanceof KesalahanKatalog && err.status === 415,
  );
  await assert.rejects(
    periksaFoto(fileMulter(jpegDimensiBesar(5000, 4000), 'image/jpeg')),
    err => err instanceof KesalahanKatalog && err.status === 415,
  );

  // PNG korup tengah & PNG header IHDR valid isi IDAT rusak -> 415
  const pngKorupTengah = Buffer.concat([png.subarray(0, 8), Buffer.from('rusak-di-tengah-chunk'), png.subarray(-12)]);
  await assert.rejects(
    periksaFoto(fileMulter(pngKorupTengah, 'image/png')),
    err => err instanceof KesalahanKatalog && err.status === 415,
  );
  await assert.rejects(
    periksaFoto(fileMulter(pngDenganHeaderValidIsiRusak(png), 'image/png')),
    err => err instanceof KesalahanKatalog && err.status === 415,
  );

  // KASUS KRITIS FASE 4: JPEG header SOF0+SOS valid tetapi isi scan korup & scan kosong -> WAJIB DITOLAK 415!
  await assert.rejects(
    periksaFoto(fileMulter(jpegHeaderValidScanRusak(jpg, false), 'image/jpeg')),
    err => err instanceof KesalahanKatalog && err.status === 415,
  );
  await assert.rejects(
    periksaFoto(fileMulter(jpegHeaderValidScanRusak(jpg, true), 'image/jpeg')),
    err => err instanceof KesalahanKatalog && err.status === 415,
  );
});

test('Cloudinary: simpan/baca privat, gambar rusak ditolak sebelum unggah, gangguan 503, dan rollback aman', async () => {
  const { png, jpg } = await buatGambarValid();
  const penyimpanan = new Map();
  const dihapus = [];
  let jumlahUnggah = 0;
  let modeKlien = 'normal';

  aturKlienCloudinaryUntukUji({
    async unggah(publicId, bytes) {
      jumlahUnggah++;
      if (modeKlien === 'dimensi-berlebih') {
        penyimpanan.set(publicId, bytes);
        return { format: 'png', width: 5000, height: 4000 };
      }
      if (modeKlien === 'gangguan') {
        throw Object.assign(new Error('connect ECONNREFUSED'), { code: 'ECONNREFUSED' });
      }
      penyimpanan.set(publicId, bytes);
      return { format: bytes[0] === 137 ? 'png' : 'jpg', width: 32, height: 24 };
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
    // JPEG scan korup ditolak di siapkanFoto SEBELUM menyentuh Cloudinary (jumlahUnggah tetap 0)
    await assert.rejects(
      siapkanFoto(fileMulter(jpegHeaderValidScanRusak(jpg, false), 'image/jpeg')),
      err => err instanceof KesalahanKatalog && err.status === 415,
    );
    assert.equal(jumlahUnggah, 0);

    // PNG & JPEG valid tersimpan dan terbaca byte identik
    const siapPng = await siapkanFoto(fileMulter(png, 'image/png'));
    await tulisFoto(siapPng);
    assert.deepEqual((await bacaFoto(siapPng.key)).bytes, png);

    const siapJpg = await siapkanFoto(fileMulter(jpg, 'image/jpeg'));
    await tulisFoto(siapJpg);
    assert.deepEqual((await bacaFoto(siapJpg.key)).bytes, jpg);

    // Dimensi > 16 MP dari respons Cloudinary -> aset langsung dihapus & ditolak 415
    modeKlien = 'dimensi-berlebih';
    await assert.rejects(
      tulisFoto({ key: '22222222-2222-4222-8222-222222222222.png', bytes: png }),
      err => err instanceof KesalahanKatalog && err.status === 415,
    );
    assert.ok(dihapus.some(id => id.endsWith('22222222-2222-4222-8222-222222222222')));

    // Gangguan jaringan -> 503
    modeKlien = 'gangguan';
    await assert.rejects(
      tulisFoto({ key: '33333333-3333-4333-8333-333333333333.png', bytes: png }),
      err => err instanceof KesalahanKatalog && err.status === 503,
    );

    // Kegagalan DB: aset yatim dihapus, foto asli yang masih dirujuk tidak dihapus
    modeKlien = 'normal';
    const dbSimulasi = (dirujuk) => ({
      select: () => ({ from: () => ({ where: () => ({ limit: async () => (dirujuk ? [{ id: 2 }] : []) }) }) }),
    });
    const hapusSebelum = dihapus.length;
    await hapusJikaLepas(dbSimulasi(true), siapPng.key);
    assert.equal(dihapus.length, hapusSebelum);
    await hapusJikaLepas(dbSimulasi(false), siapJpg.key);
    assert.equal(dihapus.length, hapusSebelum + 1);
    assert.deepEqual((await bacaFoto(siapPng.key)).bytes, png);
  } finally {
    aturKlienCloudinaryUntukUji(undefined);
  }
});

test('Pemilihan mode penyimpanan foto tetap aman (lokal default, UPLOAD_DIR paksa lokal, parsial ditolak)', () => {
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
