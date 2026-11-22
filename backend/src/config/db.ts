import mysql from "mysql2/promise";
import { drizzle } from "drizzle-orm/mysql2";
import { opsiKoneksi } from "./koneksi";

// Satu pool MySQL dan satu instance Drizzle ORM untuk seluruh aplikasi RakRapi.
export const pool = mysql.createPool(opsiKoneksi());
export const db = drizzle(pool);
