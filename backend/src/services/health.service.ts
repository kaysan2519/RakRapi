import { sql } from "drizzle-orm";
import { db } from "../config/db";

export async function namaDatabaseAktif(): Promise<string | undefined> {
  try {
    const [baris] = await db.execute(sql`SELECT DATABASE() AS nama_database`);
    if (Array.isArray(baris)) {
      return baris[0]?.nama_database;
    }
  } catch {
    // Respons health hanya menampilkan status layanan jika koneksi gagal.
  }
  return undefined;
}
