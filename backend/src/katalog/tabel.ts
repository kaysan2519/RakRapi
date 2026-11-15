import { decimal, int, mysqlTable, varchar } from "drizzle-orm/mysql-core";

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
