import { desc, eq, sql } from "drizzle-orm";
import { db } from "../config/db";
import { lowongan } from "../config/schema";
import { KesalahanKatalog } from "../middleware/error.middleware";

export async function daftarLowongan(termasukDitutup: boolean) {
  const filter = termasukDitutup ? undefined : eq(lowongan.aktif, true);
  return db.select().from(lowongan).where(filter).orderBy(desc(lowongan.id));
}

export async function bukaLowongan(judul: string) {
  // MySQL menetapkan ID dan status awal. Akun aplikasi hanya boleh mengisi judul.
  const [hasil] = await db.execute(sql`INSERT INTO ${lowongan} (judul) VALUES (${judul})`);
  return { id: hasil.insertId, judul, aktif: true };
}

export async function tutupLowongan(id: number) {
  const [hasil] = await db.update(lowongan).set({ aktif: false }).where(eq(lowongan.id, id));
  if (hasil.affectedRows === 0) {
    throw new KesalahanKatalog(404, "Lowongan tidak ditemukan.");
  }
}
