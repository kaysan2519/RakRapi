import { eq, sql } from "drizzle-orm";
import { int, mysqlTable, varchar } from "drizzle-orm/mysql-core";
import { authDb } from "../config/db";

// Pemetaan untuk query ke tabel Laragon yang sudah ada.
const users = mysqlTable("users", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  nama: varchar("nama", { length: 100 }).notNull(),
  email: varchar("email", { length: 255 }).notNull(),
  passwordHash: varchar("password_hash", { length: 255 }).notNull(),
  role: varchar("role", { length: 10, enum: ["pemilik", "pegawai"] }).notNull(),
});

const profil = { id: users.id, nama: users.nama, email: users.email, role: users.role };
export type Role = typeof users.$inferSelect.role;

export async function tambahPegawai(nama: string, email: string, hash: string) {
  // Akun aplikasi hanya boleh INSERT tiga kolom ini. MySQL menetapkan role pegawai.
  const [result] = await authDb.execute(sql`
    INSERT INTO users (nama, email, password_hash) VALUES (${nama}, ${email}, ${hash})
  `);
  return result.insertId;
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
