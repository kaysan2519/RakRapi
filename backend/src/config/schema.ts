import { boolean, decimal, int, mysqlTable, varchar } from "drizzle-orm/mysql-core";

// Pemetaan untuk query ke tabel Laragon yang sudah ada.
export const users = mysqlTable("users", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  nama: varchar("nama", { length: 100 }).notNull(),
  email: varchar("email", { length: 255 }).notNull(),
  passwordHash: varchar("password_hash", { length: 255 }).notNull(),
  role: varchar("role", { length: 10, enum: ["pemilik", "pegawai", "warga"] }).notNull(),
});

export type Role = typeof users.$inferSelect.role;

export const lowongan = mysqlTable("lowongan", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  judul: varchar("judul", { length: 150 }).notNull(),
  aktif: boolean("aktif").notNull().default(true),
});

export const kategori = mysqlTable("kategori", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  nama: varchar("nama", { length: 100 }).notNull(),
});

export const barang = mysqlTable("barang", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  kategori_id: int("kategori_id", { unsigned: true }).notNull(),
  nama: varchar("nama", { length: 150 }).notNull(),
  harga_rupiah: int("harga_rupiah", { unsigned: true }).notNull(),
  stok: decimal("stok", { precision: 12, scale: 3 }).notNull(),
  satuan: varchar("satuan", { length: 20 }).notNull(),
  foto_key: varchar("foto_key", { length: 255 }).notNull(),
});
