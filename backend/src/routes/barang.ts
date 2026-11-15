import { Router } from "express";
import { asc, eq } from "drizzle-orm";
import { perluLogin } from "../auth/session";
import { barangDenganKategori, sertakanUrlFoto } from "../katalog/barang";
import { barang } from "../katalog/tabel";
import { bilanganBulat, KesalahanKatalog } from "../katalog/validasi";

export const barangRouter = Router();
barangRouter.use(perluLogin);

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
