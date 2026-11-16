import mysql from "mysql2/promise";
import { drizzle } from "drizzle-orm/mysql2";

function createPool(user: string | undefined, password: string | undefined, database = process.env.DB_NAME ?? "rakrapi") {
  return mysql.createPool({
    host: process.env.DB_HOST ?? "127.0.0.1",
    port: Number(process.env.DB_PORT ?? 3306),
    user,
    password,
    database,
    connectTimeout: 3000,
  });
}

export const db = drizzle(createPool(process.env.DB_USER, process.env.DB_PASSWORD));
export const authDb = drizzle(createPool(process.env.AUTH_DB_USER, process.env.AUTH_DB_PASSWORD, process.env.AUTH_DB_NAME));
export const pegawaiPool = createPool(process.env.PEGAWAI_DB_USER, process.env.PEGAWAI_DB_PASSWORD, process.env.AUTH_DB_NAME);
export const catalogPool = createPool(process.env.CATALOG_DB_USER, process.env.CATALOG_DB_PASSWORD, process.env.CATALOG_DB_NAME);
export const catalogDb = drizzle(catalogPool);
