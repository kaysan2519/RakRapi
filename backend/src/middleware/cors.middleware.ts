import type { RequestHandler } from "express";

// Mengatur CORS sesuai CORS_ORIGIN di .env (* untuk development, atau daftar domain web).
export const aturCors: RequestHandler = (req, res, next) => {
  const origin = req.get("Origin");
  if (!origin) {
    next();
    return;
  }

  const daftar = (process.env.CORS_ORIGIN ?? "")
    .split(",")
    .map(item => item.trim().replace(/\/+$/, ""))
    .filter(Boolean);
  const izinkanSemua = daftar.includes("*");
  const originCocok = !izinkanSemua && daftar.includes(origin);

  if (izinkanSemua || originCocok) {
    res.set("Access-Control-Allow-Origin", izinkanSemua ? "*" : origin);
    if (!izinkanSemua) res.vary("Origin");
    res.set("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
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
