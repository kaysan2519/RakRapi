import { eq, sql } from "drizzle-orm";
import { int, mysqlTable, varchar } from "drizzle-orm/mysql-core";
import type { ProcedureCallPacket, RowDataPacket } from "mysql2/promise";
import { authDb, pegawaiPool } from "../config/db";

// Pemetaan untuk query ke tabel Laragon yang sudah ada.
const users = mysqlTable("users", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  nama: varchar("nama", { length: 100 }).notNull(),
  email: varchar("email", { length: 255 }).notNull(),
  passwordHash: varchar("password_hash", { length: 255 }).notNull(),
  role: varchar("role", { length: 10, enum: ["pemilik", "pegawai", "warga"] }).notNull(),
});

const profil = { id: users.id, nama: users.nama, email: users.email, role: users.role };
export type Role = typeof users.$inferSelect.role;

export async function tambahWarga(nama: string, email: string, hash: string) {
  return authDb.transaction(async tx => {
    const [result] = await tx.execute(sql`
      INSERT INTO users (nama, email, password_hash) VALUES (${nama}, ${email}, ${hash})
    `);
    const [akun] = await tx.select({ role: users.role }).from(users).where(eq(users.id, result.insertId));
    // Batalkan pendaftaran jika database masih memakai default lama.
    if (akun?.role !== "warga") {
      throw new Error("Default role warga belum tersedia.");
    }
    return result.insertId;
  });
}

export async function tambahPegawai(nama: string, email: string, hash: string) {
  if (!process.env.PEGAWAI_DB_USER || !process.env.PEGAWAI_DB_PASSWORD) {
    throw new Error("Koneksi pembuatan pegawai belum siap.");
  }
  const [hasil] = await pegawaiPool.execute<ProcedureCallPacket<(RowDataPacket & { id: number })[]>>(
    "CALL tambah_pegawai(?, ?, ?)", [nama, email, hash],
  );
  return hasil[0][0].id;
}

export async function cariUntukLogin(email: string) {
  const [user] = await authDb.select({ ...profil, passwordHash: users.passwordHash })
    .from(users).where(eq(users.email, email)).limit(1);
  return user;
}

export async function ambilProfil(id: number) {
  const [user] = await authDb.select(profil).from(users).where(eq(users.id, id)).limit(1);
  return user;
}
