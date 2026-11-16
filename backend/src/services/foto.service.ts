import { randomUUID } from "node:crypto";
import { mkdir, readFile, readdir, unlink, writeFile } from "node:fs/promises";
import path from "node:path";
import { eq } from "drizzle-orm";
import { drizzle, type MySql2Database } from "drizzle-orm/mysql2";
import type { RowDataPacket } from "mysql2";
import { catalogPool } from "../config/db";
import { barang } from "../config/schema";
import { KesalahanKatalog } from "../middleware/error.middleware";
import { periksaFoto } from "../validations/foto.validation";

const root = path.resolve(process.env.UPLOAD_DIR || path.join(__dirname, "../../private/uploads"));
const namaDB = process.env.CATALOG_DB_NAME ?? process.env.DB_NAME ?? "rakrapi";
const folder = path.join(root, "db-" + encodeURIComponent(namaDB));
// Nama file buatan backend: UUID versi 4 dengan ekstensi .jpg atau .png.
const polaKeyFoto = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png)$/;

export async function siapkanFoto(file: Express.Multer.File) {
  const ekstensi = await periksaFoto(file);
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
  await mkdir(folder, { recursive: true });
  await writeFile(path.join(folder, foto.key), foto.bytes, { flag: "wx", flush: true });
}

export async function bacaFoto(key: string) {
  if (!polaKeyFoto.test(key)) {
    throw new KesalahanKatalog(404, "Foto tidak ditemukan.");
  }

  const bytes = await readFile(path.join(folder, key));
  const mime = key.endsWith(".png") ? "image/png" : "image/jpeg";
  return { bytes, mime };
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

  try {
    await unlink(path.join(folder, key));
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code !== "ENOENT") {
      throw err;
    }
  }
}

export async function pulihkanFoto() {
  // Hanya hapus file buatan aplikasi yang sudah dipastikan tidak dirujuk.
  await denganKunciFoto(async db => {
    await mkdir(folder, { recursive: true });
    for (const file of await readdir(folder, { withFileTypes: true })) {
      if (file.isFile() && polaKeyFoto.test(file.name)) {
        await hapusJikaLepas(db, file.name);
      }
    }
  });
}
