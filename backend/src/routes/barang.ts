import { Router, type Request, type RequestHandler } from "express";
import { asc, eq } from "drizzle-orm";
import type { MySql2Database } from "drizzle-orm/mysql2";
import { perluLogin, perluRole } from "../auth/session";
import { barangDenganKategori, sertakanUrlFoto, validasiBarang } from "../katalog/barang";
import { bacaFoto, denganKunciFoto, hapusJikaLepas, periksaFoto, tulisFoto, unggahFoto } from "../katalog/foto";
import { barang } from "../katalog/tabel";
import { bilanganBulat, KesalahanKatalog } from "../katalog/validasi";

export const barangRouter = Router();
barangRouter.use(perluLogin);
const pemilik = perluRole("pemilik");

const terimaFoto: RequestHandler = (req, res, next) => {
  unggahFoto(req, res, error => {
    if (!error) return next();
    if (error.code === "LIMIT_FILE_SIZE") return next(new KesalahanKatalog(413, "Foto maksimal 5 MiB."));
    next(new KesalahanKatalog(400, "Form tidak valid. Kirim satu file pada kolom foto."));
  });
};

function kolomForm(req: Request): Record<string, unknown> {
  const fields = req.body ?? {};
  const allowed = ["nama", "kategori_id", "harga_rupiah", "stok", "satuan"];
  if (typeof fields !== "object" || Array.isArray(fields) || Object.keys(fields).some(k => !allowed.includes(k))) {
    throw new KesalahanKatalog(400, "Kolom barang tidak dikenal.");
  }
  return fields;
}

async function cariBarang(db: MySql2Database, id: number) {
  const [lama] = await db.select().from(barang).where(eq(barang.id, id));
  if (!lama) throw new KesalahanKatalog(404, "Barang tidak ditemukan.");
  return lama;
}

async function bersihkanFoto(db: MySql2Database, key: string) {
  try { await hapusJikaLepas(db, key); }
  catch { console.warn("Pembersihan foto tertunda sampai pemulihan berikutnya."); }
}

barangRouter.get("/", async (_req, res) => {
  const rows = await barangDenganKategori().orderBy(asc(barang.nama), asc(barang.id));
  res.json({ data: rows.map(sertakanUrlFoto) });
});

barangRouter.get("/:id", async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID barang");
  const [row] = await barangDenganKategori().where(eq(barang.id, id));
  if (!row) throw new KesalahanKatalog(404, "Barang tidak ditemukan.");
  res.json({ data: sertakanUrlFoto(row) });
});

barangRouter.get("/:id/foto", async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID barang");
  const foto = await denganKunciFoto(async db => bacaFoto((await cariBarang(db, id)).foto_key));
  res.set({ "Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff" }).type(foto.mime).send(foto.bytes);
});

const simpanBarang: RequestHandler = async (req, res) => {
  const id = req.method === "PATCH" ? bilanganBulat(req.params.id, 1, "ID barang") : undefined;
  const fields = kolomForm(req);
  if (!id && !req.file) throw new KesalahanKatalog(400, "Foto barang wajib diunggah.");
  if (id && !req.file && !Object.keys(fields).length) throw new KesalahanKatalog(400, "Pilih perubahan barang.");
  const foto = req.file ? await periksaFoto(req.file) : undefined;
  const data = await denganKunciFoto(async db => {
    const lama = id ? await cariBarang(db, id) : undefined;
    const nilai = validasiBarang({ ...lama, ...fields });
    const perubahan = foto ? { ...nilai, foto_key: foto.key } : nilai;
    let savedId = id;
    try {
      if (foto) await tulisFoto(foto);
      if (id) {
        await db.update(barang).set(perubahan).where(eq(barang.id, id));
      } else {
        const [hasil] = await db.insert(barang).values({ ...nilai, foto_key: foto!.key });
        savedId = hasil.insertId;
      }
    } catch (err) {
      // Pastikan SQL benar-benar tidak merujuk file sebelum membuang file baru.
      if (foto) await bersihkanFoto(db, foto.key);
      throw err;
    }
    if (lama && foto) await bersihkanFoto(db, lama.foto_key);
    const [hasil] = await barangDenganKategori(db).where(eq(barang.id, savedId!));
    return sertakanUrlFoto(hasil);
  });
  res.status(id ? 200 : 201).json({ data });
};

barangRouter.post("/", pemilik, terimaFoto, simpanBarang);
barangRouter.patch("/:id", pemilik, terimaFoto, simpanBarang);
barangRouter.delete("/:id", pemilik, async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID barang");
  await denganKunciFoto(async db => {
    const lama = await cariBarang(db, id);
    await db.delete(barang).where(eq(barang.id, id));
    await bersihkanFoto(db, lama.foto_key);
  });
  res.status(204).end();
});
