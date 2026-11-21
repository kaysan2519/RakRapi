import { execFile } from "node:child_process";
import { inflateSync } from "node:zlib";
import { KesalahanKatalog } from "../middleware/error.middleware";

export const batasByteFoto = 5 * 1024 * 1024;
export const batasPikselFoto = 16_000_000;
export const pesanFotoTidakValid = "Gunakan foto JPEG atau PNG yang valid, maksimal 16 megapiksel.";

export interface OpsiValidasiFoto {
  platform?: NodeJS.Platform;
  pakaiCloudinary?: boolean;
}

function formatFoto(file: Express.Multer.File): "png" | "jpg" {
  const bytes = file.buffer;
  if (bytes.length > batasByteFoto) {
    throw new KesalahanKatalog(413, "Foto maksimal 5 MiB.");
  }
  if (bytes.length < 24) {
    throw new KesalahanKatalog(415, pesanFotoTidakValid);
  }

  // Cocokkan tipe yang dikirim dengan penanda awal dan akhir file.
  const awalPng = Buffer.from("89504e470d0a1a0a", "hex");
  const akhirPng = Buffer.from("0000000049454e44ae426082", "hex");
  const penandaPngCocok = bytes.subarray(0, 8).equals(awalPng)
    && bytes.subarray(-12).equals(akhirPng);
  const awalJpegCocok = bytes[0] === 255 && bytes[1] === 216;
  const akhirJpegCocok = bytes.at(-2) === 255 && bytes.at(-1) === 217;

  if (file.mimetype === "image/png" && penandaPngCocok) {
    return "png";
  }
  if (file.mimetype === "image/jpeg" && awalJpegCocok && akhirJpegCocok) {
    return "jpg";
  }
  throw new KesalahanKatalog(415, pesanFotoTidakValid);
}

// Periksa struktur chunk PNG, lebar/tinggi IHDR, serta dekompresi stream IDAT.
function dimensiPng(bytes: Buffer): { lebar: number; tinggi: number } {
  if (bytes.length < 33 || bytes.readUInt32BE(8) !== 13 || bytes.toString("ascii", 12, 16) !== "IHDR") {
    throw new KesalahanKatalog(415, pesanFotoTidakValid);
  }
  const lebar = bytes.readUInt32BE(16);
  const tinggi = bytes.readUInt32BE(20);
  if (lebar <= 0 || tinggi <= 0 || BigInt(lebar) * BigInt(tinggi) > BigInt(batasPikselFoto)) {
    throw new KesalahanKatalog(415, pesanFotoTidakValid);
  }

  let posisi = 8;
  const potonganIdat: Buffer[] = [];
  let sampaiIend = false;
  while (posisi + 12 <= bytes.length) {
    const panjang = bytes.readUInt32BE(posisi);
    const tipe = bytes.toString("ascii", posisi + 4, posisi + 8);
    const berikutnya = posisi + 12 + panjang;
    if (berikutnya > bytes.length) {
      throw new KesalahanKatalog(415, pesanFotoTidakValid);
    }
    if (tipe === "IDAT" && panjang > 0) {
      potonganIdat.push(bytes.subarray(posisi + 8, posisi + 8 + panjang));
    }
    if (tipe === "IEND") {
      sampaiIend = panjang === 0 && berikutnya === bytes.length;
      break;
    }
    posisi = berikutnya;
  }

  if (potonganIdat.length === 0 || !sampaiIend) {
    throw new KesalahanKatalog(415, pesanFotoTidakValid);
  }
  try {
    // Dekompresi aliran IDAT menolak PNG dengan header valid tetapi isi piksel rusak.
    const batasHasil = Math.min(130 * 1024 * 1024, lebar * tinggi * 8 + tinggi + 64);
    inflateSync(Buffer.concat(potonganIdat), { maxOutputLength: batasHasil });
  } catch {
    throw new KesalahanKatalog(415, pesanFotoTidakValid);
  }
  return { lebar, tinggi };
}

// Periksa struktur segmen JPEG sampai SOS serta baca lebar dan tinggi dari segmen SOF.
function dimensiJpeg(bytes: Buffer): { lebar: number; tinggi: number } {
  let posisi = 2;
  let lebar = 0;
  let tinggi = 0;
  let adaSos = false;

  while (posisi < bytes.length - 1) {
    if (bytes[posisi] !== 0xff) {
      throw new KesalahanKatalog(415, pesanFotoTidakValid);
    }
    while (posisi < bytes.length && bytes[posisi] === 0xff) {
      posisi++;
    }
    if (posisi >= bytes.length) {
      throw new KesalahanKatalog(415, pesanFotoTidakValid);
    }

    const penanda = bytes[posisi++];
    if (penanda === 0xd9) {
      break;
    }
    if (penanda === 0x01 || (penanda >= 0xd0 && penanda <= 0xd7)) {
      continue;
    }
    if (posisi + 2 > bytes.length) {
      throw new KesalahanKatalog(415, pesanFotoTidakValid);
    }

    const panjang = bytes.readUInt16BE(posisi);
    if (panjang < 2 || posisi + panjang > bytes.length) {
      throw new KesalahanKatalog(415, pesanFotoTidakValid);
    }

    const adalahSof = (penanda >= 0xc0 && penanda <= 0xc3)
      || (penanda >= 0xc5 && penanda <= 0xc7)
      || (penanda >= 0xc9 && penanda <= 0xcb)
      || (penanda >= 0xcd && penanda <= 0xcf);
    if (adalahSof) {
      if (panjang < 7) {
        throw new KesalahanKatalog(415, pesanFotoTidakValid);
      }
      tinggi = bytes.readUInt16BE(posisi + 3);
      lebar = bytes.readUInt16BE(posisi + 5);
    }

    if (penanda === 0xda) {
      adaSos = true;
      break;
    }
    posisi += panjang;
  }

  if (!adaSos || lebar <= 0 || tinggi <= 0) {
    throw new KesalahanKatalog(415, pesanFotoTidakValid);
  }
  return { lebar, tinggi };
}

export function periksaDimensiFoto(bytes: Buffer, ekstensi: "png" | "jpg") {
  const { lebar, tinggi } = ekstensi === "png" ? dimensiPng(bytes) : dimensiJpeg(bytes);
  if (lebar <= 0 || tinggi <= 0 || BigInt(lebar) * BigInt(tinggi) > BigInt(batasPikselFoto)) {
    throw new KesalahanKatalog(415, pesanFotoTidakValid);
  }
  return { lebar, tinggi };
}

// Decoder bawaan Windows membaca byte dari stdin. Nama file klien tidak dipakai.
const decodeGambar = `
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$stream=New-Object IO.MemoryStream
[Console]::OpenStandardInput().CopyTo($stream)
$stream.Position=0
try {
  $img=[Drawing.Image]::FromStream($stream,$false,$false)
  if ([long]$img.Width * $img.Height -gt 16000000) {
    exit 2
  }
  if ($img.RawFormat.Guid -eq [Drawing.Imaging.ImageFormat]::Png.Guid) {
    $type='png'
  } elseif ($img.RawFormat.Guid -eq [Drawing.Imaging.ImageFormat]::Jpeg.Guid) {
    $type='jpg'
  } else {
    exit 2
  }
  $bitmap=[Drawing.Bitmap]::new($img)
  $bitmap.Dispose()
  [Console]::Write($type)
} catch {
  exit 2
} finally {
  if ($img) {
    $img.Dispose()
  }
  $stream.Dispose()
}
`;

async function decodeWindows(bytes: Buffer, ekstensi: "png" | "jpg") {
  const formatDariDecoder = await new Promise<string>((resolve, reject) => {
    const proc = execFile("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", decodeGambar],
      { windowsHide: true, timeout: 15000 }, (error, stdout) => {
        if (!error) {
          resolve(stdout.trim());
        } else if (error.code === 2) {
          reject(new KesalahanKatalog(415, pesanFotoTidakValid));
        } else {
          reject(error);
        }
      });
    proc.stdin?.on("error", () => { /* exit decoder ditangani di callback */ });
    proc.stdin?.end(bytes);
  });
  if (formatDariDecoder !== ekstensi) {
    throw new KesalahanKatalog(415, pesanFotoTidakValid);
  }
}

export async function periksaFoto(file: Express.Multer.File, opsi: OpsiValidasiFoto = {}) {
  const ekstensi = formatFoto(file);
  const bytes = file.buffer;
  periksaDimensiFoto(bytes, ekstensi);

  const platform = opsi.platform ?? process.platform;
  if (platform === "win32") {
    // Pertahankan validasi penuh lokal pada Windows.
    await decodeWindows(bytes, ekstensi);
    return ekstensi;
  }

  // Pada Linux, decode penuh dilakukan oleh Cloudinary saat unggah (Opsi V2).
  if (!opsi.pakaiCloudinary) {
    throw new KesalahanKatalog(503, "Validasi penuh gambar pada Linux memerlukan penyimpanan Cloudinary.");
  }
  return ekstensi;
}
