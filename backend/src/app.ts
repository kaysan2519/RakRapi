import express from "express";
import { aturCors } from "./middleware/cors.middleware";
import { tanganiError } from "./middleware/error.middleware";
import { akunRouter } from "./routes/akun.routes";
import { bansosRouter } from "./routes/bansos.routes";
import { barangRouter } from "./routes/barang.routes";
import { healthRouter } from "./routes/health.routes";
import { dashboardRouter, pinRouter, tokoRouter } from "./routes/info.routes";
import { kategoriRouter } from "./routes/kategori.routes";
import { lowonganRouter } from "./routes/lowongan.routes";
import { pengumumanRouter } from "./routes/pengumuman.routes";
import { pesananRouter } from "./routes/pesanan.routes";

export const app = express();
app.use(aturCors);
app.use("/api", healthRouter);
app.use("/api/auth", express.json({ limit: "8kb" }), akunRouter);
app.use("/api/kategori", express.json({ limit: "8kb" }), kategoriRouter);
app.use("/api/barang", express.json({ limit: "16kb" }), barangRouter);
app.use("/api/pesanan", express.json({ limit: "64kb" }), pesananRouter);
app.use("/api/lowongan", express.json({ limit: "16kb" }), lowonganRouter);
app.use("/api/bansos", express.json({ limit: "16kb" }), bansosRouter);
app.use("/api/pengumuman", express.json({ limit: "16kb" }), pengumumanRouter);
app.use("/api/pin", pinRouter);
app.use("/api/toko", express.json({ limit: "16kb" }), tokoRouter);
app.use("/api/dashboard", dashboardRouter);

app.use(tanganiError);
