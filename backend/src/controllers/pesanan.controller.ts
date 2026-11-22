import type { RequestHandler } from "express";
import * as layanan from "../services/pesanan.service";
import { validasiPesanan } from "../validations/pesanan.validation";
import { bilanganBulat } from "../validations/umum.validation";

export const kirim: RequestHandler = async (req, res) => {
  const data = await layanan.buatPesanan(res.locals.user, validasiPesanan(req.body));
  res.status(201).json({ data });
};

export const daftar: RequestHandler = async (_req, res) => {
  const akun = res.locals.user;
  const data = await layanan.daftarPesanan(akun.role === "warga" ? akun.id : undefined);
  res.json({ data });
};

export const detail: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID pesanan");
  const akun = res.locals.user;
  const data = await layanan.ambilPesanan(id, akun.role === "warga" ? akun.id : undefined);
  res.json({ data });
};

export const konfirmasi: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID pesanan");
  const data = await layanan.konfirmasiPesanan(id);
  res.json({ data });
};

export const siapDiambil: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID pesanan");
  const data = await layanan.tandaiSiapDiambil(id);
  res.json({ data });
};

export const bayar: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID pesanan");
  const data = await layanan.verifikasiPembayaran(id);
  res.json({ data });
};

export const selesai: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID pesanan");
  const data = await layanan.selesaikanPesanan(id);
  res.json({ data });
};
