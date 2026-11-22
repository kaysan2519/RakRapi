import type { RequestHandler } from "express";
import * as bansos from "../services/bansos.service";
import { bilanganBulat, booleanDariInput } from "../validations/umum.validation";

export const daftarBansos: RequestHandler = async (_req, res) => {
  const pemilik = res.locals.user.role === "pemilik";
  const data = await bansos.daftarProgramBansos(pemilik);
  res.json({ data });
};

export const detailBansos: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID program bansos");
  const pemilik = res.locals.user.role === "pemilik";
  const data = await bansos.ambilDetailProgramBansos(id, pemilik);
  res.json({ data });
};

export const kirimFotoBansos: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID program bansos");
  const foto = await bansos.ambilFotoBansos(id);
  res.set({ "Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff" });
  res.type(foto.mime).send(foto.bytes);
};

export const simpanBansos: RequestHandler = async (req, res) => {
  const id = req.method === "PATCH" ? bilanganBulat(req.params.id, 1, "ID program bansos") : undefined;
  const data = await bansos.simpanProgramBansos(id, (req.body ?? {}) as Record<string, unknown>, req.file);
  res.status(id ? 200 : 201).json({ data });
};

export const pinBansos: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID program bansos");
  const isPinned = booleanDariInput(req.body?.is_pinned, true);
  const data = await bansos.ubahPinBansos(id, isPinned);
  res.json({ data });
};

export const hapusBansos: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID program bansos");
  await bansos.hapusProgramBansos(id);
  res.status(204).end();
};

export const ajukanBansos: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID program bansos");
  const data = await bansos.ajukanBansos(id, res.locals.user, (req.body ?? {}) as Record<string, unknown>);
  res.status(201).json({ data });
};

export const daftarPengajuanSaya: RequestHandler = async (_req, res) => {
  const data = await bansos.daftarPengajuanBansos(res.locals.user.id);
  res.json({ data });
};

export const daftarSemuaPengajuan: RequestHandler = async (_req, res) => {
  const data = await bansos.daftarPengajuanBansos();
  res.json({ data });
};

export const tinjauPengajuan: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID pengajuan bansos");
  const data = await bansos.tinjauPengajuanBansos(id, req.body?.status);
  res.json({ data });
};
