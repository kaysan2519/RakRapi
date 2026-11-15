import jwt from "jsonwebtoken";
import type { RequestHandler } from "express";
import { ambilProfil, type Role } from "./users";

function jwtSecret() {
  const key = process.env.JWT_SECRET;
  if (!key || Buffer.byteLength(key) < 32) {
    throw new Error("Kunci JWT belum siap");
  }

  return key;
}

export function buatToken(id: number) {
  return jwt.sign({}, jwtSecret(), {
    algorithm: "HS256", subject: String(id), issuer: "rakrapi", expiresIn: "1h",
  });
}

function idPenggunaDariToken(authorization: string | undefined): number | undefined {
  // Kata Bearer, satu spasi, lalu token tanpa spasi.
  const polaBearer = /^Bearer ([^\s]+)$/i;
  const bearer = polaBearer.exec(authorization ?? "");
  if (!bearer) {
    return undefined;
  }

  const key = jwtSecret();
  try {
    const claims = jwt.verify(bearer[1], key, { algorithms: ["HS256"], issuer: "rakrapi" });
    if (typeof claims === "string" || !claims.sub) {
      return undefined;
    }

    // Klaim sub berisi ID pengguna: 1–10 digit, tanpa nol di depan.
    const polaIdPengguna = /^[1-9]\d{0,9}$/;
    if (!polaIdPengguna.test(claims.sub)) {
      return undefined;
    }

    return Number(claims.sub);
  } catch {
    // Token tidak sah atau kedaluwarsa.
    return undefined;
  }
}

export const perluLogin: RequestHandler = async (req, res, next) => {
  const idPengguna = idPenggunaDariToken(req.get("Authorization"));
  const profil = idPengguna === undefined ? undefined : await ambilProfil(idPengguna);
  if (!profil) {
    res.status(401).json({ pesan: "Silakan masuk kembali." });
    return;
  }

  res.locals.user = profil;
  next();
};

export function perluRole(role: Role): RequestHandler {
  return (_req, res, next) => {
    if (res.locals.user?.role !== role) {
      res.status(403).json({ pesan: "Akses ditolak." });
      return;
    }
    next();
  };
}
