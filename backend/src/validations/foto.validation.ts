import { crc32 } from "node:zlib";
import { KesalahanKatalog } from "../middleware/error.middleware";

export const batasByteFoto = 5 * 1024 * 1024;
export const batasPikselFoto = 16_000_000;
export const pesanFotoTidakValid = "Gunakan foto JPG, PNG, atau WebP yang valid, maksimal 16 megapiksel.";

export type EkstensiFoto = "png" | "jpg" | "webp";

const penandaAwalPng = Buffer.from("89504e470d0a1a0a", "hex");
const bitDepthPngValid = new Set([1, 2, 4, 8, 16]);
const tipeWarnaPngValid = new Set([0, 2, 3, 4, 6]);
const markerSofJpeg = new Set([
  0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7,
  0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf,
]);
const markerLanjutanScanJpeg = new Set([0xc4, 0xda, 0xdb, 0xdd, 0xd9, 0xfe]);

function tolakFoto(): never {
  throw new KesalahanKatalog(415, pesanFotoTidakValid);
}

function periksaDimensi(lebar: number, tinggi: number) {
  if (
    !Number.isInteger(lebar)
    || !Number.isInteger(tinggi)
    || lebar <= 0
    || tinggi <= 0
    || BigInt(lebar) * BigInt(tinggi) > BigInt(batasPikselFoto)
  ) {
    tolakFoto();
  }
}

function periksaPng(bytes: Buffer) {
  if (!bytes.subarray(0, 8).equals(penandaAwalPng)) {
    tolakFoto();
  }

  let posisi = 8;
  let lebar = 0;
  let tinggi = 0;
  let adaIhdr = false;
  let adaIdat = false;
  let adaIend = false;

  while (posisi < bytes.length) {
    if (posisi + 12 > bytes.length) tolakFoto();
    const panjang = bytes.readUInt32BE(posisi);
    if (panjang > 0x7fffffff || posisi + 12 + panjang > bytes.length) tolakFoto();

    const tipe = bytes.subarray(posisi + 4, posisi + 8).toString("ascii");
    if (!/^[A-Za-z]{4}$/.test(tipe)) tolakFoto();

    // Verifikasi CRC32 bawaan Node.js pada setiap chunk (IHDR, IDAT, IEND, dll.).
    const crcTersimpan = bytes.readUInt32BE(posisi + 8 + panjang);
    const crcHitung = crc32(bytes.subarray(posisi + 4, posisi + 8 + panjang));
    if (crcHitung !== crcTersimpan) tolakFoto();

    const awalData = posisi + 8;
    if (posisi === 8) {
      if (tipe !== "IHDR" || panjang !== 13) tolakFoto();
      lebar = bytes.readUInt32BE(awalData);
      tinggi = bytes.readUInt32BE(awalData + 4);
      const bitDepth = bytes[awalData + 8];
      const tipeWarna = bytes[awalData + 9];
      const kompresi = bytes[awalData + 10];
      const filter = bytes[awalData + 11];
      const interlace = bytes[awalData + 12];
      if (
        !bitDepthPngValid.has(bitDepth)
        || !tipeWarnaPngValid.has(tipeWarna)
        || kompresi !== 0
        || filter !== 0
        || (interlace !== 0 && interlace !== 1)
      ) {
        tolakFoto();
      }
      adaIhdr = true;
    } else if (tipe === "IDAT") {
      if (panjang > 0) adaIdat = true;
    } else if (tipe === "IEND") {
      if (panjang !== 0 || posisi + 12 !== bytes.length) tolakFoto();
      adaIend = true;
      break;
    }

    posisi += 12 + panjang;
  }

  if (!adaIhdr || !adaIdat || !adaIend) tolakFoto();
  periksaDimensi(lebar, tinggi);
}

function periksaJpeg(bytes: Buffer) {
  if (bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes.at(-2) !== 0xff || bytes.at(-1) !== 0xd9) {
    tolakFoto();
  }

  let posisi = 2;
  let lebar = 0;
  let tinggi = 0;
  let adaSof = false;
  let adaSos = false;
  let sampaiEoi = false;

  while (posisi < bytes.length) {
    if (bytes[posisi] !== 0xff) tolakFoto();
    while (posisi < bytes.length && bytes[posisi] === 0xff) posisi++;
    if (posisi >= bytes.length) tolakFoto();

    const marker = bytes[posisi++];
    if (marker === 0xd9) {
      if (posisi !== bytes.length) tolakFoto();
      sampaiEoi = true;
      break;
    }
    if (marker === 0x00 || marker === 0xd8) tolakFoto();
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;

    if (posisi + 2 > bytes.length) tolakFoto();
    const panjang = bytes.readUInt16BE(posisi);
    if (panjang < 2 || posisi + panjang > bytes.length - 2) tolakFoto();

    if (markerSofJpeg.has(marker)) {
      if (panjang < 8) tolakFoto();
      const presisi = bytes[posisi + 2];
      tinggi = bytes.readUInt16BE(posisi + 3);
      lebar = bytes.readUInt16BE(posisi + 5);
      const komponen = bytes[posisi + 7];
      if ((presisi !== 8 && presisi !== 12) || (komponen !== 1 && komponen !== 3 && komponen !== 4)) {
        tolakFoto();
      }
      if (panjang !== 8 + komponen * 3) tolakFoto();
      adaSof = true;
    }

    posisi += panjang;

    if (marker === 0xda) {
      if (panjang < 6 || !adaSof) tolakFoto();
      adaSos = true;
      const awalScan = posisi;
      let ketemuMarkerBerikut = false;

      // Periksa data entropy scan setelah SOS hingga marker JPEG berikutnya atau EOI.
      while (posisi < bytes.length) {
        if (bytes[posisi] !== 0xff) {
          posisi++;
          continue;
        }
        const posisiFf = posisi;
        while (posisi < bytes.length && bytes[posisi] === 0xff) posisi++;
        if (posisi >= bytes.length) tolakFoto();
        const berikut = bytes[posisi];

        if (berikut === 0x00 || (berikut >= 0xd0 && berikut <= 0xd7)) {
          posisi++;
          continue;
        }
        if (markerLanjutanScanJpeg.has(berikut) || (berikut >= 0xe0 && berikut <= 0xef)) {
          if (posisiFf <= awalScan) tolakFoto();
          posisi = posisiFf;
          ketemuMarkerBerikut = true;
          break;
        }
        tolakFoto();
      }

      if (!ketemuMarkerBerikut) tolakFoto();
    }
  }

  if (!adaSof || !adaSos || !sampaiEoi) tolakFoto();
  periksaDimensi(lebar, tinggi);
}

function periksaWebp(bytes: Buffer) {
  if (bytes.subarray(0, 4).toString("ascii") !== "RIFF" || bytes.subarray(8, 12).toString("ascii") !== "WEBP") {
    tolakFoto();
  }
  const ukuranRiff = bytes.readUInt32LE(4);
  if (ukuranRiff < 12 || ukuranRiff + 8 !== bytes.length) tolakFoto();

  let posisi = 12;
  let lebar = 0;
  let tinggi = 0;
  let adaGambar = false;
  let modeVp8x = false;

  while (posisi < bytes.length) {
    if (posisi + 8 > bytes.length) tolakFoto();
    const fourcc = bytes.subarray(posisi, posisi + 4).toString("ascii");
    const panjang = bytes.readUInt32LE(posisi + 4);
    const awalData = posisi + 8;
    const panjangPad = panjang + (panjang % 2);
    if (awalData + panjang > bytes.length || awalData + panjangPad > bytes.length) tolakFoto();

    if (posisi === 12) {
      if (fourcc === "VP8 ") {
        if (panjang < 10) tolakFoto();
        const frameTag = bytes[awalData];
        if ((frameTag & 1) !== 0) tolakFoto();
        if (bytes[awalData + 3] !== 0x9d || bytes[awalData + 4] !== 0x01 || bytes[awalData + 5] !== 0x2a) {
          tolakFoto();
        }
        lebar = bytes.readUInt16LE(awalData + 6) & 0x3fff;
        tinggi = bytes.readUInt16LE(awalData + 8) & 0x3fff;
        adaGambar = true;
      } else if (fourcc === "VP8L") {
        if (panjang < 5 || bytes[awalData] !== 0x2f) tolakFoto();
        const bits = bytes.readUInt32LE(awalData + 1);
        lebar = (bits & 0x3fff) + 1;
        tinggi = ((bits >> 14) & 0x3fff) + 1;
        adaGambar = true;
      } else if (fourcc === "VP8X") {
        if (panjang < 10) tolakFoto();
        lebar = (bytes[awalData + 4] | (bytes[awalData + 5] << 8) | (bytes[awalData + 6] << 16)) + 1;
        tinggi = (bytes[awalData + 7] | (bytes[awalData + 8] << 8) | (bytes[awalData + 9] << 16)) + 1;
        modeVp8x = true;
      } else {
        tolakFoto();
      }
    } else if (modeVp8x && (fourcc === "VP8 " || fourcc === "VP8L" || fourcc === "ANMF") && panjang > 0) {
      adaGambar = true;
    }

    posisi = awalData + panjangPad;
  }

  if (posisi !== bytes.length || !adaGambar) tolakFoto();
  periksaDimensi(lebar, tinggi);
}

// Validasi biner bawaan Node.js (Buffer + CRC32) tanpa library pengolah gambar eksternal.
// Memeriksa ukuran file, kecocokan MIME dengan magic bytes, struktur chunk/marker, dan batas 16 MP.
export async function periksaFoto(file: Express.Multer.File): Promise<EkstensiFoto> {
  if (!file || !Buffer.isBuffer(file.buffer) || file.buffer.length === 0) {
    tolakFoto();
  }
  const bytes = file.buffer;
  if (bytes.length > batasByteFoto) {
    throw new KesalahanKatalog(413, "Foto maksimal 5 MiB.");
  }
  if (bytes.length < 24) {
    tolakFoto();
  }

  if (file.mimetype === "image/png") {
    periksaPng(bytes);
    return "png";
  }
  if (file.mimetype === "image/jpeg") {
    periksaJpeg(bytes);
    return "jpg";
  }
  if (file.mimetype === "image/webp") {
    periksaWebp(bytes);
    return "webp";
  }
  tolakFoto();
}
