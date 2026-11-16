import { asc, eq } from "drizzle-orm";
import { catalogDb } from "../config/db";
import { kategori } from "../config/schema";
import { KesalahanKatalog } from "../middleware/error.middleware";

export async function ambilDaftarKategori() {
  return catalogDb.select().from(kategori).orderBy(asc(kategori.nama));
}

export async function ambilDetailKategori(id: number) {
  const [data] = await catalogDb.select().from(kategori).where(eq(kategori.id, id));
  if (!data) {
    throw new KesalahanKatalog(404, "Kategori tidak ditemukan.");
  }
  return data;
}

export async function tambahKategori(nama: string) {
  const [hasil] = await catalogDb.insert(kategori).values({ nama });
  return { id: hasil.insertId, nama };
}

export async function ubahKategori(id: number, nama: string) {
  const [hasil] = await catalogDb.update(kategori).set({ nama }).where(eq(kategori.id, id));
  if (!hasil.affectedRows) {
    throw new KesalahanKatalog(404, "Kategori tidak ditemukan.");
  }
  return { id, nama };
}

export async function hapusKategori(id: number) {
  const [hasil] = await catalogDb.delete(kategori).where(eq(kategori.id, id));
  if (!hasil.affectedRows) {
    throw new KesalahanKatalog(404, "Kategori tidak ditemukan.");
  }
}
