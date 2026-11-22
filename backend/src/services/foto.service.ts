import { randomUUID } from "node:crypto";
import { mkdir, readFile, readdir, unlink, writeFile } from "node:fs/promises";
import path from "node:path";
import { v2 as cloudinary } from "cloudinary";
import { eq } from "drizzle-orm";
import { db } from "../config/db";
import { barang } from "../config/schema";
import { KesalahanKatalog } from "../middleware/error.middleware";
import { periksaFoto } from "../validations/foto.validation";

// Nama file buatan backend: UUID versi 4 dengan ekstensi .jpg atau .png.
const polaKeyFoto = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png)$/;

function namaDatabase() {
  return process.env.DB_NAME ?? "rakrapi";
}

function folderLokal() {
  const root = path.resolve(process.env.UPLOAD_DIR || path.join(__dirname, "../../private/uploads"));
  return path.join(root, "db-" + encodeURIComponent(namaDatabase()));
}

function kredensialCloudinary() {
  const cloudName = process.env.CLOUDINARY_CLOUD_NAME?.trim() ?? "";
  const apiKey = process.env.CLOUDINARY_API_KEY?.trim() ?? "";
  const apiSecret = process.env.CLOUDINARY_API_SECRET?.trim() ?? "";
  return {
    cloudName,
    apiKey,
    apiSecret,
    adaSebagian: Boolean(cloudName || apiKey || apiSecret),
    lengkap: Boolean(cloudName && apiKey && apiSecret),
  };
}

// Pakai Cloudinary jika kredensialnya terisi (kecuali saat UPLOAD_DIR dipakai tes lokal).
export function memakaiCloudinary(): boolean {
  if (process.env.UPLOAD_DIR) {
    return false;
  }
  const kred = kredensialCloudinary();
  if (!kred.adaSebagian) {
    return false;
  }
  if (!kred.lengkap) {
    throw new KesalahanKatalog(503, "Konfigurasi Cloudinary belum lengkap.");
  }
  return true;
}

function siapkanCloudinary() {
  const kred = kredensialCloudinary();
  cloudinary.config({
    cloud_name: kred.cloudName,
    api_key: kred.apiKey,
    api_secret: kred.apiSecret,
    secure: true,
  });
}

function publicIdDariKey(key: string) {
  const idTanpaEkstensi = key.slice(0, key.lastIndexOf("."));
  return `rakrapi/db-${encodeURIComponent(namaDatabase())}/${idTanpaEkstensi}`;
}

export async function siapkanFoto(file: Express.Multer.File) {
  const ekstensi = await periksaFoto(file);
  const key = randomUUID() + "." + ekstensi;
  return { key, bytes: file.buffer };
}

export async function tulisFoto(foto: { key: string; bytes: Buffer }) {
  if (!memakaiCloudinary()) {
    const folder = folderLokal();
    await mkdir(folder, { recursive: true });
    await writeFile(path.join(folder, foto.key), foto.bytes, { flag: "wx" });
    return;
  }

  siapkanCloudinary();
  const publicId = publicIdDariKey(foto.key);
  try {
    await new Promise<void>((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        { public_id: publicId, resource_type: "image", type: "authenticated", overwrite: false },
        error => (error ? reject(error) : resolve()),
      );
      stream.end(foto.bytes);
    });
  } catch {
    throw new KesalahanKatalog(503, "Penyimpanan foto belum tersedia.");
  }
}

export async function bacaFoto(key: string) {
  if (!polaKeyFoto.test(key)) {
    throw new KesalahanKatalog(404, "Foto tidak ditemukan.");
  }
  const ekstensi = key.endsWith(".png") ? "png" : "jpg";
  const mime = ekstensi === "png" ? "image/png" : "image/jpeg";

  if (!memakaiCloudinary()) {
    try {
      const bytes = await readFile(path.join(folderLokal(), key));
      return { bytes, mime };
    } catch {
      throw new KesalahanKatalog(404, "Foto tidak ditemukan.");
    }
  }

  siapkanCloudinary();
  // Buat URL unduh privat bertanda tangan (berlaku 60 detik) lalu baca dari server.
  const urlPrivat = cloudinary.utils.private_download_url(publicIdDariKey(key), ekstensi, {
    resource_type: "image",
    type: "authenticated",
    expires_at: Math.floor(Date.now() / 1000) + 60,
  });
  let respons: Response;
  try {
    respons = await fetch(urlPrivat, { signal: AbortSignal.timeout(15000) });
  } catch {
    throw new KesalahanKatalog(503, "Penyimpanan foto belum tersedia.");
  }
  if (respons.status === 404) {
    throw new KesalahanKatalog(404, "Foto tidak ditemukan.");
  }
  if (!respons.ok) {
    throw new KesalahanKatalog(503, "Penyimpanan foto belum tersedia.");
  }
  return { bytes: Buffer.from(await respons.arrayBuffer()), mime };
}

export async function hapusJikaLepas(key: string) {
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
    siapkanCloudinary();
    await cloudinary.uploader.destroy(publicIdDariKey(key), {
      resource_type: "image",
      type: "authenticated",
      invalidate: true,
    });
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
  const folder = folderLokal();
  await mkdir(folder, { recursive: true });
  for (const file of await readdir(folder, { withFileTypes: true })) {
    if (file.isFile() && polaKeyFoto.test(file.name)) {
      await hapusJikaLepas(file.name);
    }
  }
}
