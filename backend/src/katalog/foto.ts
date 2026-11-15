import { execFile } from "node:child_process";
import { randomUUID } from "node:crypto";
import { mkdir, readFile, readdir, unlink, writeFile } from "node:fs/promises";
import path from "node:path";
import multer from "multer";
import { eq } from "drizzle-orm";
import { drizzle, type MySql2Database } from "drizzle-orm/mysql2";
import type { RowDataPacket } from "mysql2";
import { catalogPool } from "../config/db";
import { barang } from "./tabel";
import { KesalahanKatalog } from "./validasi";

const root = path.resolve(process.env.UPLOAD_DIR || path.join(__dirname, "../../private/uploads"));
const namaDB = process.env.CATALOG_DB_NAME ?? process.env.DB_NAME ?? "rakrapi";
const folder = path.join(root, "db-" + encodeURIComponent(namaDB));
// Nama file buatan backend: UUID versi 4 dengan ekstensi .jpg atau .png.
const polaKeyFoto = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png)$/;
const batasByteFoto = 5 * 1024 * 1024;

export const unggahFoto = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: batasByteFoto + 1, files: 1, fields: 5, parts: 7, fieldSize: 1024 },
}).single("foto");

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

export async function periksaFoto(file: Express.Multer.File) {
  const bytes = file.buffer;
  if (bytes.length > batasByteFoto) {
    throw new KesalahanKatalog(413, "Foto maksimal 5 MiB.");
  }

  // Cocokkan tipe yang dikirim dengan penanda awal dan akhir file.
  const awalPng = Buffer.from("89504e470d0a1a0a", "hex");
  const akhirPng = Buffer.from("0000000049454e44ae426082", "hex");
  const penandaPngCocok = bytes.subarray(0, 8).equals(awalPng) && bytes.subarray(-12).equals(akhirPng);
  const awalJpegCocok = bytes[0] === 255 && bytes[1] === 216;
  const akhirJpegCocok = bytes.at(-2) === 255 && bytes.at(-1) === 217;

  const pesanFotoTidakValid = "Gunakan foto JPEG atau PNG yang valid, maksimal 16 megapiksel.";
  let ekstensi: "png" | "jpg";
  if (file.mimetype === "image/png" && penandaPngCocok) {
    ekstensi = "png";
  } else if (file.mimetype === "image/jpeg" && awalJpegCocok && akhirJpegCocok) {
    ekstensi = "jpg";
  } else {
    throw new KesalahanKatalog(415, pesanFotoTidakValid);
  }

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

  return { key: randomUUID() + "." + ekstensi, bytes };
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

export async function tulisFoto(foto: Awaited<ReturnType<typeof periksaFoto>>) {
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

  const [dipakai] = await db.select({ id: barang.id }).from(barang).where(eq(barang.foto_key, key)).limit(1);
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
