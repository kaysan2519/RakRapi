import { sql } from "drizzle-orm";
import { Router } from "express";
import { db } from "../config/db";

export const healthRouter = Router();

healthRouter.get("/health", async (_req, res) => {
  res.set("Cache-Control", "no-store");
  try {
    const [rows] = await db.execute(sql`SELECT DATABASE() AS nama_database`);
    if (Array.isArray(rows) && rows[0]?.nama_database === "rakrapi") {
      res.status(200).json({ status: "ok", nama_database: rows[0].nama_database });
      return;
    }
  } catch {
    // Kesalahan koneksi dan nama database yang keliru mendapat respons umum yang sama.
  }
  res.status(503).json({ status: "unavailable" });
});
