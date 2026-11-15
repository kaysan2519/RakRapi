import { int, mysqlTable, varchar } from "drizzle-orm/mysql-core";

export const kategori = mysqlTable("kategori", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  nama: varchar("nama", { length: 100 }).notNull(),
});
