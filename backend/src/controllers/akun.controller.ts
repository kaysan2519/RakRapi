import type { RequestHandler } from "express";
import {
  ambilDetailPegawai,
  berhentikanPegawai,
  daftarkanAkun,
  daftarPegawai,
  periksaLogin,
} from "../services/akun.service";
import { emailDari, validasiAkun } from "../validations/akun.validation";
import { bilanganBulat, namaValid } from "../validations/umum.validation";

export function buatAkun(role: "warga" | "pegawai"): RequestHandler {
  return async (req, res) => {
    const isian = validasiAkun(req.body?.nama, req.body?.email, req.body?.password);
    if (!isian) {
      res.status(400).json({ pesan: "Isi nama, email valid, dan sandi minimal 8 karakter, maksimal 72 byte." });
      return;
    }

    const user = await daftarkanAkun(isian.nama, isian.email, isian.password, role);
    if (!user) {
      res.status(409).json({ pesan: "Email sudah terdaftar." });
      return;
    }
    res.status(201).json({ user });
  };
}

export const login: RequestHandler = async (req, res) => {
  const email = emailDari(req.body?.email);
  const sesi = await periksaLogin(email, req.body?.password);
  if (!sesi) {
    res.status(401).json({ pesan: "Email atau sandi salah." });
    return;
  }
  res.json(sesi);
};

export const profilSendiri: RequestHandler = (_req, res) => {
  res.json({ user: res.locals.user });
};

export const aksesPemilik: RequestHandler = (_req, res) => {
  res.json({ pesan: "Akses pemilik diterima." });
};

export const listPegawai: RequestHandler = async (req, res) => {
  const statusQuery = typeof req.query.status === "string" ? req.query.status.trim() : "";
  const filter =
    statusQuery === "aktif" || statusQuery === "diberhentikan" ? statusQuery : undefined;
  const data = await daftarPegawai(filter);
  res.json({ data });
};

export const detailPegawai: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID pegawai");
  const data = await ambilDetailPegawai(id);
  res.json({ data });
};

export const nonaktifkanPegawai: RequestHandler = async (req, res) => {
  const id = bilanganBulat(req.params.id, 1, "ID pegawai");
  const alasan = namaValid(req.body?.alasan, 500, "Alasan pemberhentian");
  const data = await berhentikanPegawai(id, alasan);
  res.json({ data });
};
