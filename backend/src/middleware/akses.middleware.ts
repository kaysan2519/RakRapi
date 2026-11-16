import type { RequestHandler } from "express";
import type { Role } from "../config/schema";
import { ambilProfil, idPenggunaDariToken } from "../services/akun.service";

export const perluLogin: RequestHandler = async (req, res, next) => {
  const idPengguna = idPenggunaDariToken(req.get("Authorization"));
  if (idPengguna === undefined) {
    res.status(401).json({ pesan: "Silakan masuk kembali." });
    return;
  }

  const profil = await ambilProfil(idPengguna);
  if (!profil) {
    res.status(401).json({ pesan: "Silakan masuk kembali." });
    return;
  }

  res.locals.user = profil;
  next();
};

export function perluRole(...diizinkan: Role[]): RequestHandler {
  return (_req, res, next) => {
    if (!diizinkan.includes(res.locals.user?.role)) {
      res.status(403).json({ pesan: "Akses ditolak." });
      return;
    }
    next();
  };
}
