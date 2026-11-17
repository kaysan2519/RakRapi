import type { RequestHandler } from "express";
import * as lowongan from "../services/lowongan.service";
import { bilanganBulat, namaValid } from "../validations/umum.validation";

export const daftarLowongan: RequestHandler = async (_req, res) => {
  const pemilik = res.locals.user.role === "pemilik";
  const data = await lowongan.daftarLowongan(pemilik);
  res.json({ data });
};

export const bukaLowongan: RequestHandler = async (req, res) => {
  const judul = namaValid(req.body?.judul, 150);
  const data = await lowongan.bukaLowongan(judul);
  res.status(201).json({ data });
};

export const tutupLowongan: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID lowongan");
  await lowongan.tutupLowongan(id);
  res.status(204).end();
};
