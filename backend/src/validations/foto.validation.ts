import sharp from "sharp";
import { KesalahanKatalog } from "../middleware/error.middleware";

export const batasByteFoto = 5 * 1024 * 1024;
export const batasPikselFoto = 16_000_000;
export const pesanFotoTidakValid = "Gunakan foto JPEG atau PNG yang valid, maksimal 16 megapiksel.";

function formatFoto(file: Express.Multer.File): "png" | "jpg" {
  const bytes = file.buffer;
  if (bytes.length > batasByteFoto) {
    throw new KesalahanKatalog(413, "Foto maksimal 5 MiB.");
  }
  if (bytes.length < 24) {
    throw new KesalahanKatalog(415, pesanFotoTidakValid);
  }

  // Cocokkan MIME dengan penanda awal dan akhir file PNG/JPEG.
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

export async function periksaFoto(file: Express.Multer.File): Promise<"png" | "jpg"> {
  const ekstensi = formatFoto(file);
  try {
    // Sharp dipakai hanya untuk validasi ketat (failOn: "warning" + batas 16 MP).
    // Byte file asli tidak dikompresi atau diubah; hasil dekode langsung dibuang.
    const gambar = sharp(file.buffer, {
      failOn: "warning",
      limitInputPixels: batasPikselFoto,
      sequentialRead: true,
    });
    const info = await gambar.metadata();
    const formatCocok =
      (ekstensi === "png" && info.format === "png")
      || (ekstensi === "jpg" && info.format === "jpeg");
    const lebar = info.width ?? 0;
    const tinggi = info.height ?? 0;
    if (!formatCocok || lebar <= 0 || tinggi <= 0 || BigInt(lebar) * BigInt(tinggi) > BigInt(batasPikselFoto)) {
      throw new KesalahanKatalog(415, pesanFotoTidakValid);
    }
    await gambar.raw().toBuffer();
    return ekstensi;
  } catch (error) {
    if (error instanceof KesalahanKatalog) {
      throw error;
    }
    throw new KesalahanKatalog(415, pesanFotoTidakValid);
  }
}
