import { randomUUID } from "node:crypto";
import { mkdir, readFile, readdir, unlink, writeFile } from "node:fs/promises";
import path from "node:path";
import { v2 as cloudinary } from "cloudinary";
import { eq } from "drizzle-orm";
import { db } from "../config/db";
import { barang, lowongan, pengumuman, programBansos } from "../config/schema";
import { KesalahanKatalog } from "../middleware/error.middleware";
import { periksaFoto, pesanFotoTidakValid } from "../validations/foto.validation";

// Nama file buatan backend: UUID versi 4 dengan ekstensi .jpg, .png, atau .webp.
const polaKeyFoto = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$/;

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

// Cache memori sederhana untuk byte foto Cloudinary agar cepat saat katalog memuat banyak item.
const cacheFoto = new Map<string, { bytes: Buffer; mime: string }>();

function simpanCache(key: string, nilai: { bytes: Buffer; mime: string }) {
  if (cacheFoto.size >= 40) {
    const pertama = cacheFoto.keys().next().value;
    if (pertama) cacheFoto.delete(pertama);
  }
  cacheFoto.set(key, nilai);
}

export async function tulisFoto(foto: { key: string; bytes: Buffer }) {
  cacheFoto.delete(foto.key);
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
  } catch (error) {
    const statusCloud = (error as { http_code?: number } | null)?.http_code;
    if (statusCloud === 400) {
      throw new KesalahanKatalog(415, pesanFotoTidakValid);
    }
    throw new KesalahanKatalog(503, "Penyimpanan foto belum tersedia.");
  }
}

export async function bacaFoto(key: string) {
  if (!polaKeyFoto.test(key)) {
    throw new KesalahanKatalog(404, "Foto tidak ditemukan.");
  }
  const ekstensi = key.endsWith(".png") ? "png" : key.endsWith(".webp") ? "webp" : "jpg";
  const mime = ekstensi === "png" ? "image/png" : ekstensi === "webp" ? "image/webp" : "image/jpeg";

  if (!memakaiCloudinary()) {
    try {
      const bytes = await readFile(path.join(folderLokal(), key));
      return { bytes, mime };
    } catch {
      throw new KesalahanKatalog(404, "Foto tidak ditemukan.");
    }
  }

  const tersimpan = cacheFoto.get(key);
  if (tersimpan) {
    return tersimpan;
  }

  siapkanCloudinary();
  // Buat URL unduh privat bertanda tangan (berlaku 60 detik) lalu baca dari server.
  const urlPrivat = cloudinary.utils.private_download_url(publicIdDariKey(key), ekstensi, {
    resource_type: "image",
    type: "authenticated",
    expires_at: Math.floor(Date.now() / 1000) + 60,
  });
  let respons: Response | undefined;
  for (let percobaan = 0; percobaan < 2; percobaan++) {
    try {
      respons = await fetch(urlPrivat, { signal: AbortSignal.timeout(30000) });
      if (respons.ok || respons.status === 404) break;
    } catch {
      if (percobaan === 1) {
        throw new KesalahanKatalog(503, "Penyimpanan foto belum tersedia.");
      }
    }
  }
  if (!respons || respons.status === 404) {
    throw new KesalahanKatalog(404, "Foto tidak ditemukan.");
  }
  if (!respons.ok) {
    throw new KesalahanKatalog(503, "Penyimpanan foto belum tersedia.");
  }
  const hasil = { bytes: Buffer.from(await respons.arrayBuffer()), mime };
  simpanCache(key, hasil);
  return hasil;
}

async function masihDipakai(key: string): Promise<boolean> {
  const [diBarang] = await db.select({ id: barang.id }).from(barang).where(eq(barang.foto_key, key)).limit(1);
  if (diBarang) return true;
  const [diLowongan] = await db.select({ id: lowongan.id }).from(lowongan).where(eq(lowongan.foto_key, key)).limit(1);
  if (diLowongan) return true;
  const [diBansos] = await db.select({ id: programBansos.id }).from(programBansos).where(eq(programBansos.foto_key, key)).limit(1);
  if (diBansos) return true;
  const [diPengumuman] = await db.select({ id: pengumuman.id }).from(pengumuman).where(eq(pengumuman.foto_key, key)).limit(1);
  return Boolean(diPengumuman);
}

export async function hapusJikaLepas(key: string | null | undefined) {
  if (!key || !polaKeyFoto.test(key)) {
    return;
  }
  if (await masihDipakai(key)) {
    return;
  }
  cacheFoto.delete(key);

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

export async function bersihkanFotoAman(key: string | null | undefined) {
  if (!key) return;
  try {
    await hapusJikaLepas(key);
  } catch {
    console.warn("Pembersihan foto tertunda.");
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
