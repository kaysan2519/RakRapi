// Jalankan dari backend: node --test test/foto.cjs
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const sharp = require('sharp');
const { periksaFoto } = require('../dist/validations/foto.validation');
const { bacaFoto, memakaiCloudinary, siapkanFoto, tulisFoto } = require('../dist/services/foto.service');
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
      if (kosong) return Buffer.concat([prefix, Buffer.from([0xff, 0xd9])]);
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

async function denganEnvFoto(nilai, kerja) {
  const kunci = ['UPLOAD_DIR', 'CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET'];
  const sebelum = Object.fromEntries(kunci.map(k => [k, process.env[k]]));
  try {
    for (const k of kunci) delete process.env[k];
    Object.assign(process.env, nilai);
    return await kerja();
  } finally {
    for (const k of kunci) {
      delete process.env[k];
      if (sebelum[k] !== undefined) process.env[k] = sebelum[k];
    }
  }
}

async function buatGambarValid() {
  const png = await sharp({ create: { width: 32, height: 24, channels: 3, background: { r: 18, g: 43, b: 34 } } }).png().toBuffer();
  const jpg = await sharp({ create: { width: 32, height: 24, channels: 3, background: { r: 18, g: 43, b: 34 } } }).jpeg({ quality: 90 }).toBuffer();
  return { png, jpg };
}

test('Validasi menerima PNG/JPEG valid dan foto asli ID 2 tanpa mengubah byte asli', async () => {
  const { png, jpg } = await buatGambarValid();
  const salinanPng = Buffer.from(png);
  const salinanJpg = Buffer.from(jpg);

  assert.equal(await periksaFoto(fileMulter(png, 'image/png')), 'png');
  assert.equal(await periksaFoto(fileMulter(jpg, 'image/jpeg')), 'jpg');
  assert.equal(Buffer.compare(png, salinanPng), 0);
  assert.equal(Buffer.compare(jpg, salinanJpg), 0);

  const lokasiFotoAsli = path.join(__dirname, '../private/uploads/db-rakrapi/431a9e84-3c42-438a-b876-a2f8816c61dd.png');
  if (fs.existsSync(lokasiFotoAsli)) {
    const asli = fs.readFileSync(lokasiFotoAsli);
    assert.equal(await periksaFoto(fileMulter(asli, 'image/png')), 'png');
  }
});

test('Validasi menolak PNG korup, JPEG scan korup/kosong, MIME palsu, >5 MiB, dan >16 MP', async () => {
  const { png, jpg } = await buatGambarValid();

  await assert.rejects(periksaFoto(fileMulter(png, 'image/jpeg')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(jpg, 'image/png')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(Buffer.from('bukan gambar sama sekali ini teks biasa'), 'image/png')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(Buffer.alloc(5 * 1024 * 1024 + 1), 'image/png')), e => e instanceof KesalahanKatalog && e.status === 413);
  await assert.rejects(periksaFoto(fileMulter(pngDimensiBesar(png, 5000, 4000), 'image/png')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(jpegDimensiBesar(5000, 4000), 'image/jpeg')), e => e instanceof KesalahanKatalog && e.status === 415);

  const pngKorupTengah = Buffer.concat([png.subarray(0, 8), Buffer.from('rusak-di-tengah-chunk'), png.subarray(-12)]);
  await assert.rejects(periksaFoto(fileMulter(pngKorupTengah, 'image/png')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(pngDenganHeaderValidIsiRusak(png), 'image/png')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(jpegHeaderValidScanRusak(jpg, false), 'image/jpeg')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(jpegHeaderValidScanRusak(jpg, true), 'image/jpeg')), e => e instanceof KesalahanKatalog && e.status === 415);
});

test('Penyimpanan lokal terisolasi menyimpan dan membaca byte foto identik', async () => {
  const { png, jpg } = await buatGambarValid();
  const dirSementara = fs.mkdtempSync(path.join(os.tmpdir(), 'rakrapi-uji-foto-'));
  try {
    await denganEnvFoto({ UPLOAD_DIR: dirSementara }, async () => {
      const siapPng = await siapkanFoto(fileMulter(png, 'image/png'));
      await tulisFoto(siapPng);
      const bacaPng = await bacaFoto(siapPng.key);
      assert.equal(bacaPng.mime, 'image/png');
      assert.deepEqual(bacaPng.bytes, png);

      const siapJpg = await siapkanFoto(fileMulter(jpg, 'image/jpeg'));
      await tulisFoto(siapJpg);
      const bacaJpg = await bacaFoto(siapJpg.key);
      assert.equal(bacaJpg.mime, 'image/jpeg');
      assert.deepEqual(bacaJpg.bytes, jpg);

      await assert.rejects(bacaFoto('../terlarang.png'), e => e instanceof KesalahanKatalog && e.status === 404);
    });
  } finally {
    fs.rmSync(dirSementara, { recursive: true, force: true });
  }
});

test('Pemilihan mode penyimpanan foto aman (UPLOAD_DIR paksa lokal, Cloudinary lengkap aktif, parsial 503)', async () => {
  await denganEnvFoto({}, () => assert.equal(memakaiCloudinary(), false));
  await denganEnvFoto(
    { UPLOAD_DIR: 'C:/tmp/uji', CLOUDINARY_CLOUD_NAME: 'a', CLOUDINARY_API_KEY: 'b', CLOUDINARY_API_SECRET: 'c' },
    () => assert.equal(memakaiCloudinary(), false),
  );
  await denganEnvFoto(
    { CLOUDINARY_CLOUD_NAME: 'a', CLOUDINARY_API_KEY: 'b', CLOUDINARY_API_SECRET: 'c' },
    () => assert.equal(memakaiCloudinary(), true),
  );
  await denganEnvFoto(
    { CLOUDINARY_CLOUD_NAME: 'a' },
    () => assert.throws(() => memakaiCloudinary(), e => e instanceof KesalahanKatalog && e.status === 503),
  );
});
