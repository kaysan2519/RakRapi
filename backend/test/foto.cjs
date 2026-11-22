// Jalankan dari backend: node --test test/foto.cjs
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const zlib = require('node:zlib');
const { periksaFoto } = require('../dist/validations/foto.validation');
const { bacaFoto, memakaiCloudinary, siapkanFoto, tulisFoto } = require('../dist/services/foto.service');
const { KesalahanKatalog } = require('../dist/middleware/error.middleware');

function fileMulter(buffer, mimetype, originalname = 'uji.png') {
  return { buffer, mimetype, size: buffer.length, originalname };
}

function buatChunkPng(tipe, data) {
  const panjang = Buffer.alloc(4);
  panjang.writeUInt32BE(data.length, 0);
  const blok = Buffer.concat([Buffer.from(tipe, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(zlib.crc32(blok), 0);
  return Buffer.concat([panjang, blok, crc]);
}

// Buat PNG valid 8x8 murni dengan modul bawaan Node.js (Buffer + zlib).
function buatPngValid(lebar = 8, tinggi = 8) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(lebar, 0);
  ihdr.writeUInt32BE(tinggi, 4);
  ihdr[8] = 8; // bit depth 8
  ihdr[9] = 2; // RGB
  const rawBaris = Buffer.alloc(tinggi * (1 + lebar * 3));
  const idat = zlib.deflateSync(rawBaris);
  return Buffer.concat([
    Buffer.from('89504e470d0a1a0a', 'hex'),
    buatChunkPng('IHDR', ihdr),
    buatChunkPng('IDAT', idat),
    buatChunkPng('IEND', Buffer.alloc(0)),
  ]);
}

// JPEG baseline valid 1x1 standar (SOI, APP0, DQT, SOF0 1x1, DHT, SOS, entropy, EOI).
const jpgValidStandar = Buffer.from(
  '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AVN//2Q==',
  'base64',
);

// WebP VP8L lossless valid 1x1 standar.
const webpValidStandar = Buffer.from(
  'UklGRh4AAABXRUJQVlA4TBEAAAAvAAAAAAfQ//73v/+BiOh/AAA=',
  'base64',
);

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
  // Hitung ulang CRC32 IHDR agar benar-benar menguji pagar batas 16 MP (bukan CRC).
  const crcBaru = zlib.crc32(salinan.subarray(12, 29));
  salinan.writeUInt32BE(crcBaru, 29);
  return salinan;
}

function jpegDimensiBesar(lebar, tinggi) {
  const sof0 = Buffer.from([
    0xff, 0xc0, 0x00, 0x0b, 0x08,
    (tinggi >> 8) & 0xff, tinggi & 0xff,
    (lebar >> 8) & 0xff, lebar & 0xff,
    0x01, 0x01, 0x11, 0x00,
  ]);
  const sos = Buffer.from([0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3f, 0x00, 0x55]);
  return Buffer.concat([Buffer.from([0xff, 0xd8]), sof0, sos, Buffer.from([0xff, 0xd9])]);
}

function webpDimensiBesar(lebar, tinggi) {
  // VP8X chunk dengan lebar & tinggi melebihi 16 MP + sub-chunk VP8L kecil.
  const vp8x = Buffer.alloc(18);
  vp8x.write('VP8X', 0, 'ascii');
  vp8x.writeUInt32LE(10, 4);
  const w = lebar - 1;
  const h = tinggi - 1;
  vp8x[12] = w & 0xff; vp8x[13] = (w >> 8) & 0xff; vp8x[14] = (w >> 16) & 0xff;
  vp8x[15] = h & 0xff; vp8x[16] = (h >> 8) & 0xff; vp8x[17] = (h >> 16) & 0xff;
  const vp8l = Buffer.from([0x56, 0x50, 0x38, 0x4c, 0x06, 0x00, 0x00, 0x00, 0x2f, 0x00, 0x00, 0x00, 0x00, 0x00]);
  const body = Buffer.concat([Buffer.from('WEBP', 'ascii'), vp8x, vp8l]);
  const hdr = Buffer.alloc(8);
  hdr.write('RIFF', 0, 'ascii');
  hdr.writeUInt32LE(body.length, 4);
  return Buffer.concat([hdr, body]);
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

test('Validasi menerima PNG, JPEG, WebP valid, aset WebP, dan foto asli ID 2 tanpa mengubah byte asli', async () => {
  const png = buatPngValid();
  const jpg = Buffer.from(jpgValidStandar);
  const webp = Buffer.from(webpValidStandar);
  const salinanPng = Buffer.from(png);
  const salinanJpg = Buffer.from(jpg);
  const salinanWebp = Buffer.from(webp);

  assert.equal(await periksaFoto(fileMulter(png, 'image/png', 'uji.png')), 'png');
  assert.equal(await periksaFoto(fileMulter(jpg, 'image/jpeg', 'uji.jpg')), 'jpg');
  assert.equal(await periksaFoto(fileMulter(webp, 'image/webp', 'uji.webp')), 'webp');
  assert.equal(Buffer.compare(png, salinanPng), 0);
  assert.equal(Buffer.compare(jpg, salinanJpg), 0);
  assert.equal(Buffer.compare(webp, salinanWebp), 0);

  const asetWebp = path.join(__dirname, '../../frontend/assets/images/ilustrasi_toko.webp');
  if (fs.existsSync(asetWebp)) {
    const bytesWebp = fs.readFileSync(asetWebp);
    assert.equal(await periksaFoto(fileMulter(bytesWebp, 'image/webp', 'ilustrasi_toko.webp')), 'webp');
  }

  const lokasiFotoAsli = path.join(__dirname, '../private/uploads/db-rakrapi/431a9e84-3c42-438a-b876-a2f8816c61dd.png');
  if (fs.existsSync(lokasiFotoAsli)) {
    const asli = fs.readFileSync(lokasiFotoAsli);
    assert.equal(await periksaFoto(fileMulter(asli, 'image/png', 'asli.png')), 'png');
  }
});

test('Validasi menolak file kosong, format tidak didukung, MIME palsu, file menyamar, >5 MiB, >16 MP, dan gambar korup', async () => {
  const png = buatPngValid();
  const jpg = Buffer.from(jpgValidStandar);
  const webp = Buffer.from(webpValidStandar);

  // File kosong dan terlalu pendek
  await assert.rejects(periksaFoto(fileMulter(Buffer.alloc(0), 'image/png')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(Buffer.from('12345'), 'image/jpeg')), e => e instanceof KesalahanKatalog && e.status === 415);

  // Format tidak didukung (GIF, BMP, SVG, PDF)
  const gif = Buffer.concat([Buffer.from('GIF89a', 'ascii'), Buffer.alloc(32)]);
  const bmp = Buffer.concat([Buffer.from('BM', 'ascii'), Buffer.alloc(40)]);
  const svg = Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>');
  const pdf = Buffer.from('%PDF-1.7\n1 0 obj << /Type /Catalog >> endobj\n%%EOF');
  await assert.rejects(periksaFoto(fileMulter(gif, 'image/gif', 'anim.gif')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(bmp, 'image/bmp', 'img.bmp')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(svg, 'image/svg+xml', 'ikon.svg')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(pdf, 'application/pdf', 'doc.pdf')), e => e instanceof KesalahanKatalog && e.status === 415);

  // MIME palsu (magic bytes tidak cocok MIME)
  await assert.rejects(periksaFoto(fileMulter(png, 'image/jpeg', 'palsu.jpg')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(jpg, 'image/png', 'palsu.png')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(webp, 'image/png', 'palsu.png')), e => e instanceof KesalahanKatalog && e.status === 415);

  // File teks/skrip menyamar sebagai .png / .jpg
  await assert.rejects(periksaFoto(fileMulter(Buffer.from('<?php echo "halo"; ?> bukan gambar sama sekali'), 'image/png', 'shell.png')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(svg, 'image/png', 'xss.png')), e => e instanceof KesalahanKatalog && e.status === 415);

  // Melebihi 5 MiB (413)
  await assert.rejects(periksaFoto(fileMulter(Buffer.alloc(5 * 1024 * 1024 + 1), 'image/png', 'besar.png')), e => e instanceof KesalahanKatalog && e.status === 413);

  // Melebihi 16 MP (415) untuk PNG, JPEG, dan WebP
  await assert.rejects(periksaFoto(fileMulter(pngDimensiBesar(png, 5000, 4000), 'image/png', '16mp.png')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(jpegDimensiBesar(5000, 4000), 'image/jpeg', '16mp.jpg')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(webpDimensiBesar(5000, 4000), 'image/webp', '16mp.webp')), e => e instanceof KesalahanKatalog && e.status === 415);

  // Gambar rusak: PNG korup chunk/CRC, JPEG scan korup/kosong, WebP RIFF/sync rusak
  const pngKorupTengah = Buffer.concat([png.subarray(0, 8), Buffer.from('rusak-di-tengah-chunk'), png.subarray(-12)]);
  await assert.rejects(periksaFoto(fileMulter(pngKorupTengah, 'image/png')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(pngDenganHeaderValidIsiRusak(png), 'image/png')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(jpegHeaderValidScanRusak(jpg, false), 'image/jpeg')), e => e instanceof KesalahanKatalog && e.status === 415);
  await assert.rejects(periksaFoto(fileMulter(jpegHeaderValidScanRusak(jpg, true), 'image/jpeg')), e => e instanceof KesalahanKatalog && e.status === 415);
  const webpRusak = Buffer.from('RIFFxxxxWEBPVP8 xxxxxxxxxxxxxxxx', 'ascii');
  await assert.rejects(periksaFoto(fileMulter(webpRusak, 'image/webp')), e => e instanceof KesalahanKatalog && e.status === 415);
});

test('Penyimpanan lokal terisolasi menyimpan dan membaca byte foto identik (PNG, JPEG, WebP)', async () => {
  const png = buatPngValid();
  const jpg = Buffer.from(jpgValidStandar);
  const webp = Buffer.from(webpValidStandar);
  const dirSementara = fs.mkdtempSync(path.join(os.tmpdir(), 'rakrapi-uji-foto-'));
  try {
    await denganEnvFoto({ UPLOAD_DIR: dirSementara }, async () => {
      for (const [bytes, mime] of [[png, 'image/png'], [jpg, 'image/jpeg'], [webp, 'image/webp']]) {
        const siap = await siapkanFoto(fileMulter(bytes, mime));
        await tulisFoto(siap);
        const baca = await bacaFoto(siap.key);
        assert.equal(baca.mime, mime);
        assert.deepEqual(baca.bytes, bytes);
      }

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
