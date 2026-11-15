import { Router } from "express";
import { asc, eq } from "drizzle-orm";
import { perluLogin, perluRole } from "../auth/session";
import { catalogDb } from "../config/db";
import { kategori } from "../katalog/tabel";
import { bilanganBulat, KesalahanKatalog, namaValid } from "../katalog/validasi";

export const kategoriRouter = Router();
kategoriRouter.use(perluLogin, perluRole("pemilik"));

kategoriRouter.get("/", async (_req, res) => {
  const data = await catalogDb.select().from(kategori).orderBy(asc(kategori.nama));
  res.json({ data });
});

kategoriRouter.get("/:id", async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID kategori");
  const [data] = await catalogDb.select().from(kategori).where(eq(kategori.id, id));
  if (!data) throw new KesalahanKatalog(404, "Kategori tidak ditemukan.");
  res.json({ data });
});

kategoriRouter.post("/", async (req, res) => {
  const nama = namaValid(req.body?.nama, 100);
  const [hasil] = await catalogDb.insert(kategori).values({ nama });
  res.status(201).json({ data: { id: hasil.insertId, nama } });
});

kategoriRouter.patch("/:id", async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID kategori");
  const nama = namaValid(req.body?.nama, 100);
  const [hasil] = await catalogDb.update(kategori).set({ nama }).where(eq(kategori.id, id));
  if (!hasil.affectedRows) throw new KesalahanKatalog(404, "Kategori tidak ditemukan.");
  res.json({ data: { id, nama } });
});

kategoriRouter.delete("/:id", async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID kategori");
  const [hasil] = await catalogDb.delete(kategori).where(eq(kategori.id, id));
  if (!hasil.affectedRows) throw new KesalahanKatalog(404, "Kategori tidak ditemukan.");
  res.status(204).end();
});
