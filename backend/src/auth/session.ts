import jwt from "jsonwebtoken";
import type { RequestHandler } from "express";
import { ambilProfil, type Role } from "./users";

function jwtSecret() {
  const key = process.env.JWT_SECRET;
  if (!key || Buffer.byteLength(key) < 32) throw new Error("Kunci JWT belum siap");
  return key;
}

export function buatToken(id: number) {
  return jwt.sign({}, jwtSecret(), {
    algorithm: "HS256", subject: String(id), issuer: "rakrapi", expiresIn: "1h",
  });
}

export const perluLogin: RequestHandler = async (req, res, next) => {
  const bearer = /^Bearer ([^\s]+)$/i.exec(req.get("Authorization") ?? "");
  if (bearer) {
    const key = jwtSecret();
    let id: number | undefined;
    try {
      const claims = jwt.verify(bearer[1], key, { algorithms: ["HS256"], issuer: "rakrapi" });
      if (typeof claims !== "string" && claims.sub && /^[1-9]\d{0,9}$/.test(claims.sub)) {
        id = Number(claims.sub);
      }
    } catch {
      // Token salah atau kedaluwarsa mendapat respons 401 yang sama.
    }
    if (id) {
      const user = await ambilProfil(id);
      if (user) {
        res.locals.user = user;
        next();
        return;
      }
    }
  }
  res.status(401).json({ pesan: "Silakan masuk kembali." });
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
