import { asc, eq, sql } from "drizzle-orm";
import { db } from "../config/db";
import { barang, kategori } from "../config/schema";
import { KesalahanKatalog, kodeMysql } from "../middleware/error.middleware";

export async function ambilDaftarKategori() {
  const hasil = await db
    .select({
      id: kategori.id,
      nama: kategori.nama,
      jumlah_produk: sql<number>`COUNT(${barang.id})`,
    })
    .from(kategori)
    .leftJoin(barang, eq(barang.kategori_id, kategori.id))
    .groupBy(kategori.id, kategori.nama)
    .orderBy(asc(kategori.nama));

  return hasil.map(k => ({ ...k, jumlah_produk: Number(k.jumlah_produk) }));
}

export async function ambilDetailKategori(id: number) {
  const [data] = await db.select().from(kategori).where(eq(kategori.id, id));
  if (!data) {
    throw new KesalahanKatalog(404, "Kategori tidak ditemukan.");
  }
  return data;
}

export async function tambahKategori(nama: string) {
  try {
    const [hasil] = await db.insert(kategori).values({ nama });
    return { id: hasil.insertId, nama, jumlah_produk: 0 };
  } catch (err) {
    if (kodeMysql(err) === "ER_DUP_ENTRY") {
      throw new KesalahanKatalog(409, "Nama kategori sudah digunakan.");
    }
    throw err;
  }
}

export async function ubahKategori(id: number, nama: string) {
  try {
    const [hasil] = await db.update(kategori).set({ nama }).where(eq(kategori.id, id));
    if (!hasil.affectedRows) {
      throw new KesalahanKatalog(404, "Kategori tidak ditemukan.");
    }
    return { id, nama };
  } catch (err) {
    if (kodeMysql(err) === "ER_DUP_ENTRY") {
      throw new KesalahanKatalog(409, "Nama kategori sudah digunakan.");
    }
    throw err;
  }
}

export async function hapusKategori(id: number) {
  try {
    const [hasil] = await db.delete(kategori).where(eq(kategori.id, id));
    if (!hasil.affectedRows) {
      throw new KesalahanKatalog(404, "Kategori tidak ditemukan.");
    }
  } catch (err) {
    const kode = kodeMysql(err);
    if (kode === "ER_ROW_IS_REFERENCED" || kode === "ER_ROW_IS_REFERENCED_2") {
      throw new KesalahanKatalog(
        409,
        "Kategori ini masih digunakan. Kategori bisa dihapus setelah tidak ada barang yang menggunakannya.",
      );
    }
    throw err;
  }
}
