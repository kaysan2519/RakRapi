import type { RequestHandler } from "express";
import * as info from "../services/info.service";

export const daftarPin: RequestHandler = async (req, res) => {
  const pemilik = res.locals.user.role === "pemilik";
  const mintaSemua = pemilik && (req.query.semua === "1" || req.query.semua === "true");
  const data = await info.daftarInformasiPin(!mintaSemua);
  res.json({ data });
};

export const detailToko: RequestHandler = async (_req, res) => {
  const data = await info.ambilInfoToko();
  res.json({ data });
};

export const ubahToko: RequestHandler = async (req, res) => {
  const data = await info.perbaruiInfoToko((req.body ?? {}) as Record<string, unknown>);
  res.json({ data });
};

export const ringkasanDashboard: RequestHandler = async (_req, res) => {
  const data = await info.ambilRingkasanDashboard();
  res.json({ data });
};
