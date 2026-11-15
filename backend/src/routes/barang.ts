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
    if (!error) {
      return next();
    }
    if (error.code === "LIMIT_FILE_SIZE") {
      return next(new KesalahanKatalog(413, "Foto maksimal 5 MiB."));
    }

    next(new KesalahanKatalog(400, "Form tidak valid. Kirim satu file pada kolom foto."));
  });
};

function kolomForm(req: Request): Record<string, unknown> {
  const isian = req.body ?? {};
  if (typeof isian !== "object" || Array.isArray(isian)) {
    throw new KesalahanKatalog(400, "Kolom barang tidak dikenal.");
  }

  const kolomDiizinkan = ["nama", "kategori_id", "harga_rupiah", "stok", "satuan"];
  const adaKolomAsing = Object.keys(isian).some(kolom => !kolomDiizinkan.includes(kolom));
  if (adaKolomAsing) {
    throw new KesalahanKatalog(400, "Kolom barang tidak dikenal.");
  }

  return isian;
}

async function cariBarang(db: MySql2Database, id: number) {
  const [dataBarang] = await db.select().from(barang).where(eq(barang.id, id));
  if (!dataBarang) {
    throw new KesalahanKatalog(404, "Barang tidak ditemukan.");
  }

  return dataBarang;
}

async function bersihkanFoto(db: MySql2Database, key: string) {
  try {
    await hapusJikaLepas(db, key);
  } catch {
    console.warn("Pembersihan foto tertunda sampai pemulihan berikutnya.");
  }
}

barangRouter.get("/", async (_req, res) => {
  const rows = await barangDenganKategori().orderBy(asc(barang.nama), asc(barang.id));
  res.json({ data: rows.map(sertakanUrlFoto) });
});

barangRouter.get("/:id", async function detailBarang(req, res) {
  const idBarang = bilanganBulat(req.params.id, 1, "ID barang");
  const [detail] = await barangDenganKategori().where(eq(barang.id, idBarang));
  if (!detail) {
    throw new KesalahanKatalog(404, "Barang tidak ditemukan.");
  }

  res.json({ data: sertakanUrlFoto(detail) });
});

barangRouter.get("/:id/foto", async function kirimFotoBarang(req, res) {
  const idBarang = bilanganBulat(req.params.id, 1, "ID barang");
  // Baca referensi dan file dalam satu kunci agar fotonya tidak berganti di tengah pembacaan.
  const foto = await denganKunciFoto(async db => {
    const dataBarang = await cariBarang(db, idBarang);
    return bacaFoto(dataBarang.foto_key);
  });
  res.set({ "Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff" });
  res.type(foto.mime).send(foto.bytes);
});

const simpanBarang: RequestHandler = async (req, res) => {
  let idBarang: number | undefined;
  if (req.method === "PATCH") {
    idBarang = bilanganBulat(req.params.id, 1, "ID barang");
  }

  const isian = kolomForm(req);
  if (!idBarang && !req.file) {
    throw new KesalahanKatalog(400, "Foto barang wajib diunggah.");
  }
  if (idBarang && !req.file && Object.keys(isian).length === 0) {
    throw new KesalahanKatalog(400, "Pilih perubahan barang.");
  }

  const fotoBaru = req.file ? await periksaFoto(req.file) : undefined;
  const data = await denganKunciFoto(async db => {
    const barangLama = idBarang ? await cariBarang(db, idBarang) : undefined;
    const nilai = validasiBarang({ ...barangLama, ...isian });
    let idTersimpan: number;

    try {
      if (fotoBaru) {
        await tulisFoto(fotoBaru);
      }

      if (idBarang) {
        const perubahan: Partial<typeof barang.$inferInsert> = { ...nilai };
        if (fotoBaru) {
          perubahan.foto_key = fotoBaru.key;
        }
        await db.update(barang).set(perubahan).where(eq(barang.id, idBarang));
        idTersimpan = idBarang;
      } else {
        // Untuk barang baru, foto sudah diwajibkan sebelum validasi.
        const [hasil] = await db.insert(barang).values({ ...nilai, foto_key: fotoBaru!.key });
        idTersimpan = hasil.insertId;
      }
    } catch (err) {
      // Pastikan SQL benar-benar tidak merujuk file sebelum membuang file baru.
      if (fotoBaru) {
        await bersihkanFoto(db, fotoBaru.key);
      }
      throw err;
    }
    if (barangLama && fotoBaru) {
      await bersihkanFoto(db, barangLama.foto_key);
    }

    const [hasil] = await barangDenganKategori(db).where(eq(barang.id, idTersimpan));
    return sertakanUrlFoto(hasil);
  });

  const status = idBarang ? 200 : 201;
  res.status(status).json({ data });
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
