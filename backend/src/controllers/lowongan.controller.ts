import type { RequestHandler } from "express";
import * as lowongan from "../services/lowongan.service";
import { bilanganBulat, booleanDariInput } from "../validations/umum.validation";

export const daftarLowongan: RequestHandler = async (_req, res) => {
  const pemilik = res.locals.user.role === "pemilik";
  const data = await lowongan.daftarLowongan(pemilik);
  res.json({ data });
};

export const detailLowongan: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID lowongan");
  const pemilik = res.locals.user.role === "pemilik";
  const data = await lowongan.ambilDetailLowongan(id, pemilik);
  res.json({ data });
};

export const kirimFotoLowongan: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID lowongan");
  const foto = await lowongan.ambilFotoLowongan(id);
  res.set({ "Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff" });
  res.type(foto.mime).send(foto.bytes);
};

export const simpanLowongan: RequestHandler = async (req, res) => {
  const id = req.method === "PATCH" ? bilanganBulat(req.params.id, 1, "ID lowongan") : undefined;
  const data = await lowongan.simpanLowongan(id, (req.body ?? {}) as Record<string, unknown>, req.file);
  res.status(id ? 200 : 201).json({ data });
};

export const tutupLowongan: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID lowongan");
  await lowongan.tutupLowongan(id);
  res.status(204).end();
};

export const pinLowongan: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID lowongan");
  const isPinned = booleanDariInput(req.body?.is_pinned, true);
  const data = await lowongan.ubahPinLowongan(id, isPinned);
  res.json({ data });
};

export const hapusLowongan: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID lowongan");
  await lowongan.hapusLowongan(id);
  res.status(204).end();
};

export const ajukanLamaran: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID lowongan");
  const data = await lowongan.ajukanLamaran(id, res.locals.user, (req.body ?? {}) as Record<string, unknown>);
  res.status(201).json({ data });
};

export const daftarLamaranSaya: RequestHandler = async (_req, res) => {
  const data = await lowongan.daftarLamaran(res.locals.user.id);
  res.json({ data });
};

export const daftarSemuaLamaran: RequestHandler = async (_req, res) => {
  const data = await lowongan.daftarLamaran();
  res.json({ data });
};

export const tinjauLamaran: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID lamaran");
  const data = await lowongan.tinjauLamaran(id, req.body?.status);
  res.json({ data });
};
