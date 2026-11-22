import type { RequestHandler } from "express";
import * as barangService from "../services/barang.service";
import { kolomForm } from "../validations/barang.validation";
import { bilanganBulat } from "../validations/umum.validation";

export const detailBarang: RequestHandler = async (req, res) => {
  const idDariUrl = req.params.id;
  const idBarang = bilanganBulat(idDariUrl, 1, "ID barang");
  const data = await barangService.ambilDetailBarang(idBarang);
  res.json({ data });
};

export const daftarBarang: RequestHandler = async (req, res) => {
  const qMentah = typeof req.query.q === "string" ? req.query.q.trim() : "";
  const katMentah = typeof req.query.kategori_id === "string" ? req.query.kategori_id.trim() : "";
  const kategoriId = katMentah ? bilanganBulat(katMentah, 1, "Kategori") : undefined;
  const data = await barangService.ambilDaftarBarang({
    q: qMentah || undefined,
    kategoriId,
  });
  res.json({ data });
};

export const kirimFotoBarang: RequestHandler = async (req, res) => {
  const idBarang = bilanganBulat(req.params.id, 1, "ID barang");
  const foto = await barangService.ambilFotoBarang(idBarang);

  res.set({ "Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff" });
  res.type(foto.mime).send(foto.bytes);
};

export const simpanBarang: RequestHandler = async (req, res) => {
  let idBarang: number | undefined;
  if (req.method === "PATCH") {
    idBarang = bilanganBulat(req.params.id, 1, "ID barang");
  }

  const isian = kolomForm(req.body);
  const data = await barangService.simpanBarang(idBarang, isian, req.file);
  const status = idBarang ? 200 : 201;
  res.status(status).json({ data });
};

export const hapusBarang: RequestHandler = async (req, res) => {
  const idBarang = bilanganBulat(req.params.id, 1, "ID barang");
  await barangService.hapusBarang(idBarang);
  res.status(204).end();
};
