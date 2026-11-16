import type { RequestHandler } from "express";
import { namaDatabaseAktif } from "../services/health.service";

export const periksaHealth: RequestHandler = async (_req, res) => {
  res.set("Cache-Control", "no-store");
  const namaDatabase = await namaDatabaseAktif();
  if (namaDatabase === "rakrapi") {
    res.status(200).json({ status: "ok", nama_database: namaDatabase });
    return;
  }
  res.status(503).json({ status: "unavailable" });
};
