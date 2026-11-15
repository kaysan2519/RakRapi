import mysql from "mysql2/promise";
import { drizzle } from "drizzle-orm/mysql2";

function connect(user: string | undefined, password: string | undefined) {
  const pool = mysql.createPool({
    host: process.env.DB_HOST ?? "127.0.0.1",
    port: Number(process.env.DB_PORT ?? 3306),
    user,
    password,
    database: process.env.DB_NAME ?? "rakrapi",
    connectTimeout: 3000,
  });
  return drizzle(pool);
}

export const db = connect(process.env.DB_USER, process.env.DB_PASSWORD);
export const authDb = connect(process.env.AUTH_DB_USER, process.env.AUTH_DB_PASSWORD);
