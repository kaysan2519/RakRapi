import type { RequestHandler } from "express";
import * as kategoriService from "../services/kategori.service";
import { bilanganBulat, namaValid } from "../validations/umum.validation";

export const daftarKategori: RequestHandler = async (_req, res) => {
  const data = await kategoriService.ambilDaftarKategori();
  res.json({ data });
};

export const detailKategori: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID kategori");
  const data = await kategoriService.ambilDetailKategori(id);
  res.json({ data });
};

export const tambahKategori: RequestHandler = async (req, res) => {
  const nama = namaValid(req.body?.nama, 100);
  const data = await kategoriService.tambahKategori(nama);
  res.status(201).json({ data });
};

export const ubahKategori: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID kategori");
  const nama = namaValid(req.body?.nama, 100);
  const data = await kategoriService.ubahKategori(id, nama);
  res.json({ data });
};

export const hapusKategori: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID kategori");
  await kategoriService.hapusKategori(id);
  res.status(204).end();
};
