import { randomUUID } from "node:crypto";
import { mkdir, readFile, readdir, unlink, writeFile } from "node:fs/promises";
import path from "node:path";
import { v2 as cloudinary } from "cloudinary";
import { eq } from "drizzle-orm";
import { drizzle, type MySql2Database } from "drizzle-orm/mysql2";
import type { RowDataPacket } from "mysql2";
import { catalogPool } from "../config/db";
import { barang } from "../config/schema";
import { KesalahanKatalog } from "../middleware/error.middleware";
import { batasPikselFoto, periksaFoto, pesanFotoTidakValid } from "../validations/foto.validation";

// Nama file buatan backend: UUID versi 4 dengan ekstensi .jpg atau .png.
const polaKeyFoto = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png)$/;

export interface HasilUnggahCloudinary {
  format?: string;
  width?: number;
  height?: number;
}

export interface KlienCloudinary {
  unggah(publicId: string, bytes: Buffer): Promise<HasilUnggahCloudinary>;
  unduh(publicId: string, ekstensi: "png" | "jpg"): Promise<Buffer>;
  hapus(publicId: string): Promise<void>;
}

let klienUji: KlienCloudinary | undefined;

export function aturKlienCloudinaryUntukUji(klien: KlienCloudinary | undefined) {
  klienUji = klien;
}

function namaDatabaseKatalog() {
  return process.env.CATALOG_DB_NAME ?? process.env.DB_NAME ?? "rakrapi";
}

function folderLokal() {
  // Nama database sama, tetapi file Aiven tidak boleh bercampur dengan katalog Laragon.
  const folderLingkungan = process.env.DB_MODE === "aiven" ? "uploads-aiven" : "uploads";
  const root = path.resolve(process.env.UPLOAD_DIR || path.join(__dirname, "../../private", folderLingkungan));
  return path.join(root, "db-" + encodeURIComponent(namaDatabaseKatalog()));
}

function kredensialCloudinary() {
  const cloudName = process.env.CLOUDINARY_CLOUD_NAME?.trim() ?? "";
  const apiKey = process.env.CLOUDINARY_API_KEY?.trim() ?? "";
  const apiSecret = process.env.CLOUDINARY_API_SECRET?.trim() ?? "";
  const adaSebagian = Boolean(cloudName || apiKey || apiSecret);
  const lengkap = Boolean(cloudName && apiKey && apiSecret);
  return { cloudName, apiKey, apiSecret, adaSebagian, lengkap };
}

export function memakaiCloudinary(): boolean {
  if (klienUji) {
    return true;
  }
  const mode = process.env.FOTO_STORAGE?.trim().toLowerCase();
  if (mode === "lokal") {
    return false;
  }
  const kred = kredensialCloudinary();
  if (mode === "cloudinary") {
    if (!kred.lengkap) {
      throw new KesalahanKatalog(503, "Konfigurasi Cloudinary belum lengkap.");
    }
    return true;
  }
  // Runner uji lokal mengatur UPLOAD_DIR sementara agar tidak memakai penyimpanan cloud.
  if (process.env.UPLOAD_DIR) {
    return false;
  }
  if (kred.adaSebagian) {
    if (!kred.lengkap) {
      throw new KesalahanKatalog(503, "Konfigurasi Cloudinary belum lengkap.");
    }
    return true;
  }
  return false;
}

function publicIdDariKey(key: string) {
  const idTanpaEkstensi = key.slice(0, key.lastIndexOf("."));
  return `rakrapi/db-${encodeURIComponent(namaDatabaseKatalog())}/${idTanpaEkstensi}`;
}

function ekstensiDariKey(key: string): "png" | "jpg" {
  return key.endsWith(".png") ? "png" : "jpg";
}

function normalisasiFormat(format: string | undefined): "png" | "jpg" | undefined {
  const nilai = format?.trim().toLowerCase();
  if (nilai === "png") return "png";
  if (nilai === "jpg" || nilai === "jpeg") return "jpg";
  return undefined;
}

function petakanErrorCloudinary(error: unknown): KesalahanKatalog {
  if (error instanceof KesalahanKatalog) {
    return error;
  }
  const err = error as { http_code?: number; message?: string } | undefined;
  const kodeHttp = err?.http_code;
  const pesan = (err?.message ?? "").toLowerCase();
  if (kodeHttp === 413 || pesan.includes("file size too large")) {
    return new KesalahanKatalog(413, "Foto maksimal 5 MiB.");
  }
  if (
    kodeHttp === 400
    || pesan.includes("invalid image")
    || pesan.includes("unsupported")
    || pesan.includes("corrupt")
    || pesan.includes("megapixel")
    || pesan.includes("image file")
  ) {
    return new KesalahanKatalog(415, pesanFotoTidakValid);
  }
  return new KesalahanKatalog(503, "Penyimpanan foto belum tersedia.");
}

function buatKlienCloudinaryResmi(): KlienCloudinary {
  const kred = kredensialCloudinary();
  if (!kred.lengkap) {
    throw new KesalahanKatalog(503, "Konfigurasi Cloudinary belum lengkap.");
  }
  cloudinary.config({
    cloud_name: kred.cloudName,
    api_key: kred.apiKey,
    api_secret: kred.apiSecret,
    secure: true,
  });

  return {
    unggah(publicId, bytes) {
      return new Promise<HasilUnggahCloudinary>((resolve, reject) => {
        const stream = cloudinary.uploader.upload_stream(
          {
            public_id: publicId,
            resource_type: "image",
            type: "authenticated",
            allowed_formats: ["png", "jpg"],
            overwrite: false,
            invalidate: false,
          },
          (error, result) => {
            if (error || !result) {
              reject(error ?? new Error("Unggah Cloudinary tidak mengembalikan hasil."));
              return;
            }
            resolve({ format: result.format, width: result.width, height: result.height });
          },
        );
        stream.on("error", reject);
        stream.end(bytes);
      });
    },
    async unduh(publicId, ekstensi) {
      // Signed URL hanya dipakai di sisi backend dan kedaluwarsa dalam 60 detik.
      const urlPrivat = cloudinary.utils.private_download_url(publicId, ekstensi, {
        resource_type: "image",
        type: "authenticated",
        expires_at: Math.floor(Date.now() / 1000) + 60,
      });
      const respons = await fetch(urlPrivat, { signal: AbortSignal.timeout(15000) });
      if (respons.status === 404) {
        throw new KesalahanKatalog(404, "Foto tidak ditemukan.");
      }
      if (!respons.ok) {
        throw new KesalahanKatalog(503, "Penyimpanan foto belum tersedia.");
      }
      return Buffer.from(await respons.arrayBuffer());
    },
    async hapus(publicId) {
      const hasil = await cloudinary.uploader.destroy(publicId, {
        resource_type: "image",
        type: "authenticated",
        invalidate: true,
      });
      if (hasil?.result && hasil.result !== "ok" && hasil.result !== "not found") {
        throw new Error("Penghapusan aset Cloudinary gagal.");
      }
    },
  };
}

function klienCloudinaryAktif(): KlienCloudinary {
  return klienUji ?? buatKlienCloudinaryResmi();
}

export async function siapkanFoto(file: Express.Multer.File) {
  const ekstensi = await periksaFoto(file, { pakaiCloudinary: memakaiCloudinary() });
  const key = randomUUID() + "." + ekstensi;
  return { key, bytes: file.buffer };
}

// Kunci per database menjaga penulisan file, perubahan referensi, dan pemulihan
// saat restart tetap berurutan, termasuk jika dua proses backend berjalan.
export async function denganKunciFoto<T>(kerja: (db: MySql2Database) => Promise<T>) {
  const conn = await catalogPool.getConnection();
  const lock = "CONCAT('foto:', LEFT(SHA2(DATABASE(), 256), 58))";
  let gagalMelepasKunci = false;
  try {
    const [[row]] = await conn.query<RowDataPacket[]>("SELECT GET_LOCK(" + lock + ", 8) AS didapat");
    if (row.didapat !== 1) {
      throw new KesalahanKatalog(503, "Penyimpanan foto sedang sibuk.");
    }

    try {
      return await kerja(drizzle(conn));
    } finally {
      try {
        await conn.query("SELECT RELEASE_LOCK(" + lock + ")");
      } catch {
        gagalMelepasKunci = true;
      }
    }
  } finally {
    // Jangan kembalikan koneksi ke pool jika mungkin masih memegang kunci.
    if (gagalMelepasKunci) {
      conn.destroy();
    } else {
      conn.release();
    }
  }
}

export async function tulisFoto(foto: { key: string; bytes: Buffer }) {
  if (!memakaiCloudinary()) {
    const folder = folderLokal();
    await mkdir(folder, { recursive: true });
    await writeFile(path.join(folder, foto.key), foto.bytes, { flag: "wx", flush: true });
    return;
  }

  const klien = klienCloudinaryAktif();
  const publicId = publicIdDariKey(foto.key);
  const ekstensi = ekstensiDariKey(foto.key);
  let hasil: HasilUnggahCloudinary;
  try {
    hasil = await klien.unggah(publicId, foto.bytes);
  } catch (error) {
    throw petakanErrorCloudinary(error);
  }

  const formatHasil = normalisasiFormat(hasil.format);
  const lebar = hasil.width ?? 0;
  const tinggi = hasil.height ?? 0;
  const dimensiValid = Number.isInteger(lebar)
    && Number.isInteger(tinggi)
    && lebar > 0
    && tinggi > 0
    && BigInt(lebar) * BigInt(tinggi) <= BigInt(batasPikselFoto);

  if (formatHasil !== ekstensi || !dimensiValid) {
    await klien.hapus(publicId).catch(() => { /* pembersihan aset gagal dicatat di luar */ });
    throw new KesalahanKatalog(415, pesanFotoTidakValid);
  }
}

export async function bacaFoto(key: string) {
  if (!polaKeyFoto.test(key)) {
    throw new KesalahanKatalog(404, "Foto tidak ditemukan.");
  }

  const ekstensi = ekstensiDariKey(key);
  const mime = ekstensi === "png" ? "image/png" : "image/jpeg";
  if (!memakaiCloudinary()) {
    const bytes = await readFile(path.join(folderLokal(), key));
    return { bytes, mime };
  }

  try {
    const bytes = await klienCloudinaryAktif().unduh(publicIdDariKey(key), ekstensi);
    return { bytes, mime };
  } catch (error) {
    if (error instanceof KesalahanKatalog) {
      throw error;
    }
    throw new KesalahanKatalog(503, "Penyimpanan foto belum tersedia.");
  }
}

export async function hapusJikaLepas(db: MySql2Database, key: string) {
  if (!polaKeyFoto.test(key)) {
    return;
  }

  const [dipakai] = await db
    .select({ id: barang.id })
    .from(barang)
    .where(eq(barang.foto_key, key))
    .limit(1);
  if (dipakai) {
    return;
  }

  if (memakaiCloudinary()) {
    await klienCloudinaryAktif().hapus(publicIdDariKey(key));
    return;
  }

  try {
    await unlink(path.join(folderLokal(), key));
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code !== "ENOENT") {
      throw err;
    }
  }
}

export async function pulihkanFoto() {
  if (memakaiCloudinary()) {
    return;
  }
  // Hanya hapus file buatan aplikasi yang sudah dipastikan tidak dirujuk.
  await denganKunciFoto(async db => {
    const folder = folderLokal();
    await mkdir(folder, { recursive: true });
    for (const file of await readdir(folder, { withFileTypes: true })) {
      if (file.isFile() && polaKeyFoto.test(file.name)) {
        await hapusJikaLepas(db, file.name);
      }
    }
  });
}
