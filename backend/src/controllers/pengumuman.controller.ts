import type { RequestHandler } from "express";
import * as pengumuman from "../services/pengumuman.service";
import { bilanganBulat, booleanDariInput } from "../validations/umum.validation";

export const daftarPengumuman: RequestHandler = async (_req, res) => {
  const pemilik = res.locals.user.role === "pemilik";
  const data = await pengumuman.daftarPengumuman(pemilik);
  res.json({ data });
};

export const detailPengumuman: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID pengumuman");
  const pemilik = res.locals.user.role === "pemilik";
  const data = await pengumuman.ambilDetailPengumuman(id, pemilik);
  res.json({ data });
};

export const kirimFotoPengumuman: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID pengumuman");
  const foto = await pengumuman.ambilFotoPengumuman(id);
  res.set({ "Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff" });
  res.type(foto.mime).send(foto.bytes);
};

export const simpanPengumuman: RequestHandler = async (req, res) => {
  const id = req.method === "PATCH" ? bilanganBulat(req.params.id, 1, "ID pengumuman") : undefined;
  const data = await pengumuman.simpanPengumuman(id, (req.body ?? {}) as Record<string, unknown>, req.file);
  res.status(id ? 200 : 201).json({ data });
};

export const pinPengumuman: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID pengumuman");
  const isPinned = booleanDariInput(req.body?.is_pinned, true);
  const data = await pengumuman.ubahPinPengumuman(id, isPinned);
  res.json({ data });
};

export const hapusPengumuman: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID pengumuman");
  await pengumuman.hapusPengumuman(id);
  res.status(204).end();
};
