import type { RequestHandler } from "express";

function daftarOriginDiizinkan(): Set<string> {
  const daftar = (process.env.CORS_ORIGIN ?? "")
    .split(",")
    .map(origin => origin.trim().replace(/\/+$/, ""))
    .filter(origin => origin.length > 0 && origin !== "*");
  return new Set(daftar);
}

// Hanya izinkan domain web yang terdaftar di CORS_ORIGIN; tidak menggantikan JWT/role.
export const aturCors: RequestHandler = (req, res, next) => {
  const origin = req.get("Origin");
  if (!origin) {
    next();
    return;
  }

  res.vary("Origin");
  if (daftarOriginDiizinkan().has(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
    res.set("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
    res.set("Access-Control-Max-Age", "600");
    if (req.method === "OPTIONS") {
      res.status(204).end();
      return;
    }
    next();
    return;
  }

  if (req.method === "OPTIONS") {
    res.status(403).end();
    return;
  }
  next();
};
