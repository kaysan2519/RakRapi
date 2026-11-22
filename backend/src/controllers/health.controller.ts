import type { RequestHandler } from "express";
import { namaDatabaseAktif } from "../services/health.service";

export const periksaHealth: RequestHandler = async (_req, res) => {
  res.set("Cache-Control", "no-store");
  const targetDatabase = process.env.DB_NAME?.trim() || "rakrapi";
  const namaDatabase = await namaDatabaseAktif();
  if (namaDatabase === targetDatabase) {
    res.status(200).json({ status: "ok", nama_database: namaDatabase });
    return;
  }
  res.status(503).json({ status: "unavailable" });
};
